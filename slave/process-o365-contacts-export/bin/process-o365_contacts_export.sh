#!/bin/bash

PROTOCOL_VERSION='3.0.0'

function process {
	FROM_PERUN="${WORK_DIR}/o365_contacts_export"
	
	#Target export file can be changed in pre-script
	if [ ! "${TARGET_EXPORT}" ]; then
		TARGET_EXPORT="~/data/o365_emails.mu"
	fi

	#Target script which can managed export file from perun can be changed in pre-script
	if [ ! "${TARGET_SCRIPT}" ]; then
		TARGET_SCRIPT="~/send_to_inet.sh"
	fi

	if [ ! "${TARGET_SCRIPT_OPTIONS}" ]; then
		TARGET_SCRIPT_OPTIONS="o365_emails.mu"
	fi

	TARGET_COMMAND="${TARGET_SCRIPT} ${TARGET_SCRIPT_OPTIONS} ${TARGET_EXPORT}"

	### Status codes
	I_EXPORT_PROCESSED=(0 "Export file ${FROM_PERUN} was processed correctly!")
	E_CANNOT_COPY_EXPORT_FILE=(50 "Cannot copy file from perun ${FROM_PERUN} to target location ${TARGET_EXPORT}!")
	E_TARGET_SCRIPTS_ERROR=(51 "Target script ${TARGET_SCRIPT} ended with error for command: '${TARGET_COMMAND}'!")

	create_lock
	
	catch_error E_CANNOT_COPY_EXPORT_FILE cp ${FROM_PERUN} ${TARGET_EXPORT}

	catch_error E_TARGET_SCRIPTS_ERROR ${TARGET_COMMAND}

	log_msg I_EXPORT_PROCESSED
}
