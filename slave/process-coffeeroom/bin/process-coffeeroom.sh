#!/bin/bash

PROTOCOL_VERSION='3.0.0'


function process {
	FILE_USERS="users.scim"
	FILE_GROUPS="groups.scim"

	CHANGED=0

	### Status codes
	I_CHANGED=(0 '${FILE} updated')
	I_NOT_CHANGED=(0 '${FILE} has not changed')
	E_CHMOD=(51 'Cannot chmod on $WORK_DIR/$FILE')


	create_lock

	for FILE in $FILE_USERS $FILE_GROUPS ; do

		# Destination file doesn't exist
		if [ ! -f ${FILE} ]; then
			catch_error E_CHMOD chmod 0644 "$WORK_DIR/$FILE"
		fi

	done

	HOME_DIR=`eval echo ~`

	for FILE in $FILE_USERS $FILE_GROUPS ; do
		diff_mv_sync "$WORK_DIR/$FILE" "$HOME_DIR/$FILE"

		if [ $? -eq 0 ]; then
			log_msg I_CHANGED
			CHANGED=1
		else
			log_msg I_NOT_CHANGED
		fi
	done

	if [ $CHANGED -eq 1 ]; then
		jq -s '{groups: .[0], users: .[1]}' "$WORK_DIR/groups.scim" "$WORK_DIR/users.scim" | curl -k -X POST -H "Content-Type: application/json" -H "access-token:${ACCESS_TOKEN}" --data @- "${COFFEEROOM_ENTRYPOINT}" 
	fi
}
