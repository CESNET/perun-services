#!/bin/bash

PROTOCOL_VERSION='3.1.0'


function process {
	FILE_USERS="users.csv"
	FILE_GROUPS="groups.csv"
	FILE_MEMBERSHIPS="memberships.csv"

	### Status codes
	I_CHANGED=(0 '${FILE} updated')
	I_NOT_CHANGED=(0 '${FILE} has not changed')
	E_CHMOD=(51 'Cannot chmod on $WORK_DIR/$FILE')

	create_lock

	for FILE in $FILE_USERS $FILE_GROUPS $FILE_MEMBERSHIPS ; do

		# Destination file doesn't exist
		if [ ! -f ${FILE} ]; then
			catch_error E_CHMOD chmod 0644 "$WORK_DIR/$FILE"
		fi

	done

	HOME_DIR=`eval echo ~`

	for FILE in $FILE_USERS $FILE_GROUPS $FILE_MEMBERSHIPS ; do
		diff_mv_sync "$WORK_DIR/$FILE" "$HOME_DIR/$FILE"

		if [ $? -eq 0 ]; then
			log_msg I_CHANGED
		else
			log_msg I_NOT_CHANGED
		fi
	done

	FILE_USER_DUPLICATES="$WORK_DIR/users-duplicities.csv"
	#there are some duplicates between emails, need to end with error
	if [ -s "${FILE_USER_DUPLICATES}" ]; then
		DUPLICATES=`cat $FILE_USER_DUPLICATES`
		log_warn_to_err_exit "Email duplicates: ${DUPLICATES}"
	fi
}
