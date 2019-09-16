#!/bin/bash

PROTOCOL_VERSION='3.1.0'

function process {
	DST_DIR="/tmp/"

	### Status codes
	I_CHANGED=(0 "${DST_FILE} updated")
	E_NOT_CHANGE=(50 'Cannot copy file ${FROM_PERUN} to ${DST_FILE}')
	E_FILE_NOT_EXIST=(51 'Cannot find file with destination file name in ${NAME_FILE}')

	FROM_PERUN="${WORK_DIR}/rt_bbmri"
	NAME_FILE="${WORK_DIR}/output_file_name"

	if [ ! -s "$NAME_FILE" ]; then
		log_msg E_FILE_NOT_EXIST
	fi
	DST_FILE=`cat $NAME_FILE`

	create_lock

	cp "${FROM_PERUN}" "${DST_DIR}/${DST_FILE}"

	if [ $? -eq 0 ]; then
		log_msg I_CHANGED
	else
		log_msg E_NOT_CHANGED
	fi
}
