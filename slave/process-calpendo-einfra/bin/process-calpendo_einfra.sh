#!/bin/bash

PROTOCOL_VERSION='3.0.0'

function process {

	E_MISSING_DST_PATH=(50 'Missing path of handling script (DST_SCRIPT), need to be set in pre_script.')
	E_MISSING_DST_EXIST=(51 'Handling script does not exist at the specified location (' + "${DST_SCRIPT}" + '), please check that the correct path is set in pre_script')
	E_MISSING_DST_EXEC=(52 'Handling script is not executable (' + "${DST_SCRIPT}" + '), please check that the correct permissions are set')

	if [ -z ${DST_SCRIPT} ]; then
		log_msg E_MISSING_DST_PATH
	fi

	if [ ! -f ${DST_SCRIPT} ]; then
		log_msg E_MISSING_DST_EXIST
	fi

	if [ ! -x ${DST_SCRIPT} ]; then
		log_msg E_MISSING_DST_EXEC
	fi

	create_lock

	FROM_PERUN="${WORK_DIR}/users.csv"

	${DST_SCRIPT} $FROM_PERUN

	exit $?
}
