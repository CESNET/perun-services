#!/bin/bash
PROTOCOL_VERSION='3.0.0'

function process {

	DST_DIR="/etc/heimdal-kdc/krb525d.d/"
	FROM_PERUN_DIR="${WORK_DIR}/kerberos_renewal_principals/"

	### Status codes
	I_EVERYTHING_OK=(0 'All files has been updated.')
	E_FINISHED_WITH_ERRORS=(50 'Slave script finished with errors!')

	ERROR=0

	create_lock

	# Delete all files with 'kerberos_renewal_principals prefix from destination directory
	if [[ $(find $DST_DIR -mindepth 1 -maxdepth 1 -name "kerberos_renewal_principals*") ]]; then
		if ! rm $DST_DIR/kerberos_renewal_principals*; then
        		ERROR=1
        fi
	fi

	# Copy all files from perun
	for FROM_PERUN_FILE in "$FROM_PERUN_DIR"/*
	do
		# Get name of file
		local FILE_NAME
		if ! FILE_NAME=$(basename "$FROM_PERUN_FILE"); then
			ERROR=1
			continue
		fi

		# Copy file to destination dir
		if ! cp "${FROM_PERUN_FILE}" "${DST_DIR}/${FILE_NAME}.conf"; then
			ERROR=1
		fi
	done

	if [ $ERROR -ne 0 ]; then
		log_msg E_FINISHED_WITH_ERRORS
	else
		log_msg I_EVERYTHING_OK
	fi
}
