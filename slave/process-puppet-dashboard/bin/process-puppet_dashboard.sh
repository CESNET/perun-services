#!/bin/bash
PROTOCOL_VERSION='3.0.0'

function process {

	### Status codes
	I_CHANGED=(0 "${DST_FILE} updated")
	I_NOT_CHANGED=(0 "${DST_FILE} has not changed")

	E_MISSING_DST=(50 'Missing destination of file (DST_FILE), need to be set in pre_script.')

	FROM_PERUN="${WORK_DIR}/puppet_dashboard"

	if [ -z ${DST_FILE} ]; then
		log_msg E_MISSING_DST
	fi

	create_lock

	# Create diff between old.perun and .new
	diff_mv_sync "${FROM_PERUN}" "${DST_FILE}"

	if [ $? -eq 0 ]; then
		log_msg I_CHANGED
	else
		log_msg I_NOT_CHANGED
	fi
}
