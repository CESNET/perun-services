#!/bin/bash

# Slave script for SCIM service. It gets data sent by Perun system and optionally run external script for process SCIM files.
#
#author:  Michal Prochazka
#date:	  2017-08-01
#
#

PROTOCOL_VERSION='1.0.0'

function process {
	DST_DIR="/var/spool/perun/"
	CURRENT_USER=`id -u -n`

	DST_FILE_USERS="${DST_DIR}/scim-service-users.scim"
	DST_FILE_GROUPS="${DST_DIR}/scim-service-groups.scim"

	PROCESS_SCRIPT="${LIB_DIR}/${SERVICE}/process-scim"

	### Status codes
	I_CHANGED=(0 "${DST_FILE_USERS} or ${DST_FILE_GROUPS} updated")
	I_NOT_CHANGED=(0 "${DST_FILE_USERS} and ${DST_FILE_GROUPS} has not changed")
	E_DIR_NOT_EXISTS=(100 "${DST_DIR} does not exists")
	E_DIR_NOT_WRITABLE=(101 "${DST_DIR} is not writable for user ${CURRENT_USER}")
	E_PROCESS_SCRIPT_NOT_EXECUTABLE=(102 "'${PROCESS_SCRIPT}' is not executable")
	E_PROCESS_SCRIPT_FAILED=(103 "'${PROCESS_SCRIPT}' failed")
	
	FROM_PERUN_USERS="${WORK_DIR}/users.scim"
	FROM_PERUN_GROUPS="${WORK_DIR}/groups.scim"

	if [ ! -d "${DST_DIR}" ]; then
		log_msg	E_DIR_NOT_EXISTS
	fi
	if [ ! -w "${DST_DIR}" ]; then
		log_msg	E_DIR_NOT_WRITABLE
	fi

	create_lock

	diff_mv "${FROM_PERUN_USERS}" "${DST_FILE_USERS}"
	USER_DIFF=$?
	diff_mv "${FROM_PERUN_GROUPS}" "${DST_FILE_GROUPS}"
	GROUP_DIFF=$?
	
	if [ $USER_DIFF -eq 0 ] || [ $GROUP_DIFF -eq 0 ]; then
		log_msg I_CHANGED
		# if script for processing SCIM data exists and is runnable, then run it
		if [ -x "${PROCESS_SCRIPT}" ]; then
			eval "${PROCESS_SCRIPT}" "${DST_FILE_USERS}" "${DST_FILE_GROUPS}"
			if [ $? -ne 0 ]; then
				log_msg E_PROCESS_SCRIPT_FAILED
			fi
		else
		    log_msg  E_PROCESS_SCRIPT_NOT_EXECUTABLE
		fi
	else
		log_msg I_NOT_CHANGED
	fi
}
