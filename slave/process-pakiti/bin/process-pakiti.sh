#!/bin/bash

PROTOCOL_VERSION='1.0.0'

function process {
	FROM_PERUN_DATA_DIR="${WORK_DIR}/data/"
	CACHE_DIR_FOR_PAKITI="${CACHE_DIR}/${SERVICE}/data/"

	### Status codes
	I_CHANGED=(0 'Users from file ${CACHE_FILE_FOR_PAKITI} updated')
	I_NOT_CHANGED=(0 'There is no change for users in file ${CACHE_FILE_FOR_PAKITI}.')
	E_CANNOT_CREATE_CACHE_DIR=(50 'Cannot create cache directory ${CACHE_DIR_FOR_PAKITI}.')
	E_CANNOT_CREATE_CACHE_FILE=(51 'Cannot move file ${FROM_PERUN} to cache directory ${CACHE_DIR_FOR_PAKITI}.')
	E_UPDATE_USERS_ERROR=(52 'Pakiti imports ends with error ${RETVAL}!')


	if [ -z "${PHP_LIB}" ]; then
		PHP_LIB="/usr/bin/php"
	fi

	if [ -z "${PAKITI_IMPORT_SCRIPT_PATH}" ]; then
		PAKITI_IMPORT_SCRIPT_PATH="/var/www/pakiti3/lib/modules/cli/users.php"
	fi

	if [ -z "${PAKITI_CONFIG_PATH}" ]; then
		PAKITI_CONFIG_PATH="/etc/pakiti"
	fi

	create_lock

	#If cache dir for pakiti not exists, create new one
	if [ ! -d "${CACHE_DIR_FOR_PAKITI}" ]; then
		catch_error E_CANNOT_CREATE_CACHE_DIR mkdir -p "${CACHE_DIR_FOR_PAKITI}"
	fi

	#for each file in data directory
	for FROM_PERUN in `ls ${FROM_PERUN_DATA_DIR}`; do

		#if there is already cache file, diff it against new file
		PERUN_FILE="${FROM_PERUN_DATA_DIR}/${FROM_PERUN}"
		CACHE_FILE="${CACHE_DIR_FOR_PAKITI}/${FROM_PERUN}"
		if [ -f "${CACHE_FILE}" ]; then
			diff -q "${PERUN_FILE}" "${CACHE_FILE}"
			# no changes, we can log about no changes for this specific config path and skip it
			if [ $? -eq 0 ]; then
				log_msg I_NOT_CHANGED
				continue
			fi
		fi

		#let pakiti update it's users for this specific config path
		${PHP_LIB} ${PAKITI_IMPORT_SCRIPT_PATH} --config="$PAKITI_CONFIG_PATH/Config_{$FROM_PERUN}.php" -c import < "${PERUN_FILE}"
		RETVAL=$?

		if [ $RETVAL -ne 0 ]; then
			log_msg E_UPDATE_USERS_ERROR 
		fi

		catch_error E_CANNOT_CREATE_CACHE_FILE mv -f "${PERUN_FILE}" "${CACHE_FILE}"
		log_msg I_CHANGED
	done;

	#everything is ok, scripts ends without error
	exit 0;
}
