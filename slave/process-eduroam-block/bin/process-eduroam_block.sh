#!/bin/bash
PROTOCOL_VERSION='3.0.0'

# Save file with blocked users
function process {

	FROM_PERUN="${WORK_DIR}/eduroam_block"

	DST_DIR="/etc/raddb"
	DST_FILE="$DST_DIR/blacklist"

	create_lock

	cat "${FROM_PERUN}" > "${DST_FILE}"

	if [ $? -ne 0 ]; then
		echo "Update blocked users failed. Command failed: cat '${FROM_PERUN}' > '${DST_FILE}'" >&2
	fi

	#create empty file, so the cron can check it and restart radius server to reload the data
	touch "/home/perun/blocked-file-changed"

	if [ $? -ne 0 ]; then
		echo "Create empty file failed. Command failed: touch '/home/perun/blocked-file-changed'" >&2
	fi
}
