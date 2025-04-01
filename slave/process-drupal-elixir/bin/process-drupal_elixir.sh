#!/bin/bash

PROTOCOL_VERSION='3.1.0'


function process {
	FILE_USERS="users.csv"
	FILE_GROUPS="groups.csv"
	FILE_MEMBERSHIPS="memberships.csv"
	FILE_USERS_DUPLICITIES="users-duplicities.txt"
	FILE_USERS_INVALID_NAMES="users-invalid-names.txt"

	### Status codes
	I_CHANGED=(0 '${FILE} updated')
	I_NOT_CHANGED=(0 '${FILE} has not changed')
	E_CHMOD=(51 'Cannot chmod on $WORK_DIR/$FILE')

	create_lock

	for FILE in $FILE_USERS $FILE_GROUPS $FILE_MEMBERSHIPS $FILE_USERS_DUPLICITIES $FILE_USERS_INVALID_NAMES ; do

		# Destination file doesn't exist
		if [ ! -f ${FILE} ]; then
			catch_error E_CHMOD chmod 0644 "$WORK_DIR/$FILE"
		fi

	done

	HOME_DIR=`eval echo ~`

	for FILE in $FILE_USERS $FILE_GROUPS $FILE_MEMBERSHIPS $FILE_USERS_DUPLICITIES $FILE_USERS_INVALID_NAMES ; do
		diff_mv_sync "$WORK_DIR/$FILE" "$HOME_DIR/$FILE"

		if [ $? -eq 0 ]; then
			log_msg I_CHANGED
		else
			log_msg I_NOT_CHANGED
		fi
	done

	EXIT_CODE=0
	FILE_USER_DUPLICATES="${WORK_DIR}/${FILE_USERS_DUPLICITIES}"
	#there are some duplicates between emails, need to end with warning
	if [ -s "${FILE_USER_DUPLICATES}" ]; then
		DUPLICATES=`cat $FILE_USER_DUPLICATES`
		log_warn_to_err "Email duplicates: ${DUPLICATES}"
		EXIT_CODE=1
	fi

	FILE_USER_INVALID_NAMES="${WORK_DIR}/${FILE_USERS_INVALID_NAMES}"
	#there are some users without first and/or last names, need to end with warning
	if [ -s "${FILE_USER_INVALID_NAMES}" ]; then
		INVALID_NAMES=`cat $FILE_USER_INVALID_NAMES`
		log_warn_to_err "Invalid user names: ${INVALID_NAMES}"
		EXIT_CODE=1
	fi

	exit $EXIT_CODE
}
