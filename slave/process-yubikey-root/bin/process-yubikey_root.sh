#!/bin/bash

PROTOCOL_VERSION='3.0.0'


function process {
	if [ -z "$DST_DIR" ]; then
		DST_DIR="/etc/yubico"
	fi

	if [ -z "$DST_FILE_NAME" ]; then
		DST_FILE_NAME="authorized_yubikeys"
	fi

	DST_FILE=${DST_DIR}/${DST_FILE_NAME}

	### Status codes
	I_CHANGED=(0 "${DST_FILE} updated")
	I_NOT_CHANGED=(0 "${DST_FILE} has not changed")
	E_CHOWN=(50 'Cannot chown on ${FROM_PERUN}')
	E_CHMOD=(51 'Cannot chmod on ${FROM_PERUN}')
	E_MKDIR=(52 'Cannot create directory ${DST_DIR}')

	FROM_PERUN="${WORK_DIR}/yubikey_root"

	create_lock

    # Check for /etc/yubico directory
    if [ ! -d ${DST_DIR} ]; then
        catch_error E_MKDIR mkdir -p ${DST_DIR}
    fi


	# Destination file doesn't exist
	if [ ! -f ${DST_FILE} ]; then
		catch_error E_CHOWN chown root:root $FROM_PERUN
		catch_error E_CHMOD chmod 0644 $FROM_PERUN
	fi

	diff_mv_sync "${FROM_PERUN}" "${DST_FILE}"

	if [ $? -eq 0 ]; then
		log_msg I_CHANGED
	else
		log_msg I_NOT_CHANGED
	fi
}
