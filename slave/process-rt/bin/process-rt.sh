#!/bin/bash

PROTOCOL_VERSION='3.0.0'


function process {
	DST_FILE="/tmp/rt-data"

	### Status codes
	I_CHANGED=(0 "${DST_FILE} updated")
	E_NOT_CHANGE=(50 'Cannot copy file ${FROM_PERUN} to ${DST_FILE}')

	FROM_PERUN="${WORK_DIR}/rt"

	create_lock

	cp "${FROM_PERUN}" "${DST_FILE}"

	if [ $? -eq 0 ]; then
		log_msg I_CHANGED
	else
		log_msg I_NOT_CHANGED
	fi
}
