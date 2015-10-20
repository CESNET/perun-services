#!/bin/bash

# Script for managing user membership in VOs
# Return values:
# 0 ... OK
# 1 ... Single user issue
# 2 ... VO-wide issue
# 3 ... VO-availability issue (VO does not exist or is inaccessible)

PROTOCOL_VERSION='3.0.0'

function log_both {
	logger Perun:$@
	echo $@ 1>&2
}

function process {
	### Status codes
	I_CHANGED=(0 "${DST_FILE} updated")
	I_NOT_CHANGED=(0 "${DST_FILE} has not changed")

	### Error codes ###
	E_VOMS_DELETE=(50 'Error during VOMS delete-user operation')
	E_VOMS_CREATE=(50 'Error during VOMS create-user operation')

	FROM_PERUN="${WORK_DIR}/voms"

	RETVAL=0

	create_lock

	VO_USERS=`mktemp`
	CURRENT_VO_USERS=`mktemp`
	CURRENT_VO_RAW_USERS=`mktemp`
	CAS=`mktemp`
	USER_RESPONSE=`mktemp`
	CONTACTFAIL=""
	CAFAIL=""

	# Get list of VOs
	VOS=`cat ${FROM_PERUN} | sed 's/^\([[:alnum:]_.-]*\)\t.*/\1/' | uniq`

	# Iterate through every VO and check which user will be added or removed
	for VO in `echo -e $VOS`; do
		# Get users from the VO, VOMS doesn't accept emailAddress in the DN, it must be converted to Email
		cat ${FROM_PERUN} | grep -P "^${VO}\t.*" | sed 's/emailAddress/Email/' | sort > ${VO_USERS}

		# Get current users stored in VOMS and convert lines into PERUN format. VOMS also doesn't accept emailAddress in the DN, it must be converted to Email
		voms-admin --vo "${VO}" list-users > ${CURRENT_VO_RAW_USERS}
		if [ $? -ne 0 ]; then
			log_both "VO \"${VO}\" does not exist or is inactive. Original message from voms-admin: \"`cat ${CURRENT_VO_RAW_USERS}`\""
			CONTACTFAIL="${CONTACTFAIL} ${VO}"
			RETVAL=3
			continue
		fi

		cat ${CURRENT_VO_RAW_USERS} | sed "s/\(.*\),\(.*\),\(.*\)/${VO}\t\1\t\2\t\3/" | sed 's/emailAddress/Email/' | sort > ${CURRENT_VO_USERS}

		# Get list of accepted CAs
		voms-admin --vo "${VO}" list-cas > ${CAS}
		if [ $? -ne 0 ]; then
			log_both "Failed getting accepted CAs for VO \"${VO}\". Original message from voms-admin: \"`cat ${CAS}`\""
			CAFAIL="${CAFAIL} ${VO}"
			if [ $RETVAL -lt 2 ]; then RETVAL=2; fi
			continue
		fi

		# Check who should be deleted
		while read CURRENT_VO_USER; do
			if [ `grep -c "$CURRENT_VO_USER" $VO_USERS` -eq 0 ]; then
				# User is not in VO anymore, so remove him
				while IFS=`echo -ne "\t"` read VO_SHORTNAME USER_DN CA_DN USER_EMAIL; do
					# Check if the user's certificate was issued by accepted CA
					if [ `grep -c "$CA_DN" $CAS` -gt 0 ]; then
						voms-admin --nousercert --vo "${VO_SHORTNAME}" delete-user "$USER_DN" "$CA_DN" > ${USER_RESPONSE}
						if [ $? -ne 0 ]; then
							log_both "Failed removing user from VO \"${VO}\". Original message from voms-admin: \"`cat ${USER_RESPONSE}`\""
							if [ $RETVAL -lt 1 ]; then RETVAL=1; fi
							continue
						fi
						echo VOMS user $USER_DN - $CA_DN removed from ${VO_SHORTNAME}
					fi
				done <<<"`echo -e "$CURRENT_VO_USER"`"

			fi
		done <${CURRENT_VO_USERS}

		####
		# Check who should be added
		while read VO_USER; do
			if  [ `grep -c "$VO_USER" $CURRENT_VO_USERS` -eq 0 ]; then
				# New user comming, so add him to the VO
				echo -e "$VO_USER" | while IFS=`echo -ne "\t"` read VO_SHORTNAME USER_DN CA_DN USER_EMAIL; do
					# Check if the user's certificate was issued by accepted CA
					if [ `grep -c "$CA_DN" $CAS` -gt 0 ]; then
						USER_CN=`echo $USER_DN | sed 's|^.*\/CN=\([^/]*\).*|\1|'`
						voms-admin --nousercert --vo "${VO_SHORTNAME}" create-user "$USER_DN" "$CA_DN" "$USER_CN" "$USER_EMAIL" > ${USER_RESPONSE}
						if [ $? -ne 0 ]; then
							log_both "Failed adding user to VO \"${VO}\". Original message from voms-admin: \"`cat ${USER_RESPONSE}`\""
							if [ $RETVAL -lt 1 ]; then RETVAL=1; fi
							continue
						fi
						echo VOMS user $USER_DN - $CA_DN added to ${VO_SHORTNAME}
					fi
				done
			fi
		done <${VO_USERS}
	done

	rm -f $VO_USERS
	rm -f $CURRENT_VO_USERS
	rm -f $CURRENT_VO_RAW_USERS
	rm -f $CAS
	rm -f $USER_RESPONSE

	if [ $RETVAL -gt 0 ]; then
		E_VO_FAIL=(503 "VOMS slave failed contacting VO ${CONTACTFAIL}")
		E_VO_AC_FAIL=(502 "VOMS slave failed checking CAs for VO ${CAFAIL}")
		E_VOMEMBER_FAIL=(501 'VOMS slave failed managing VO members')
		case $RETVAL in
			1)
				log_msg E_VOMEMBER_FAIL;;
			2)
				log_msg E_VO_AC_FAIL;;
			3)
				log_msg E_VO_FAIL;;
		esac
	fi

	exit $RETVAL
}
