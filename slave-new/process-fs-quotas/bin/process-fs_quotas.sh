#!/bin/bash

# List of logins who have to have directory in the /home
PROTOCOL_VERSION='3.0.0'

function process {
	FROM_PERUN="${WORK_DIR}/fs_quotas"
	
	E_CANNOT_SET_QUOTA=(50 'Cannot set quota on ${QUOTA_FS} for user ${U_UID}')
	E_PROGRAM_NOT_EXECUTABLE=(51 '${SET_QUOTA_PROGRAM} is not executable')
	E_PROGRAM_NOT_AVAILABLE=(52 '/usr/sbin/setquota is not available')
	E_SOME_QUOTA_FAILED=(53 'Quota for these uids failed: ${FAILED_UIDS}')

	DEFAULT_PROGRAM="/usr/sbin/setquota"

	create_lock

	if [ ! -z "${SET_QUOTA_PROGRAM}" ]; then
		if [ -x "${SET_QUOTA_PROGRAM}" ]; then
			SET_QUOTA="${SET_QUOTA_PROGRAM}"
		else
			log_msg E_CANNOT_SET_QUOTA
		fi
	else
		if [ -x "$DEFAULT_PROGRAM" ]; then
			SET_QUOTA=$DEFAULT_PROGRAM
			#setquota name block-softlimit block-hardlimit inode-softlimit inode-hardlimit filesystem
		  SET_QUOTA_TEMPLATE='$U_UID $SOFT_QUOTA_DATA $HARD_QUOTA_DATA $SOFT_QUOTA_FILES $HARD_QUOTA_FILES $QUOTA_FS'
		else
			log_msg E_PROGRAM_NOT_AVAILABLE
		fi
	fi

	RETVAL=0
	FAILED_UIDS=""
	# lines contains data for quota settings
	while IFS=`echo -e "\t"` read U_UID SOFT_QUOTA_DATA HARD_QUOTA_DATA SOFT_QUOTA_FILES HARD_QUOTA_FILES QUOTA_FS REST_OF_LINE; do
			SET_QUOTA_PARAMS=`eval echo $SET_QUOTA_TEMPLATE`
			#Set quota
			$SET_QUOTA $SET_QUOTA_PARAMS
			if [ $? -ne 0 ]; then
				RETVAL=1
				if [ -z $FAILED_UIDS ]; then
					FAILED_UIDS="$U_UID"
				else
					FAILED_UIDS="$FAILED_UIDS,$U_UID"
				fi
			fi
	done < "${FROM_PERUN}"

	if [ $RETVAL -gt 0 ]; then
		log_msg E_SOME_QUOTA_FAILED 
	fi
}
