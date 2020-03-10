#!/bin/bash

PROTOCOL_VERSION='3.0.0'


function process {
	
	DST_FILE="/etc/mail/perun/muni"
	FROM_PERUN="${WORK_DIR}/o365_mail_forward_export"

	### Status codes
	I_CHANGED=(0 "${DST_FILE} updated")
	I_NOT_CHANGED=(0 "${DST_FILE} has not changed")
	E_DOALIASES=(50 '/etc/mail/doaliases ended with an error')

	create_lock

	#move file if there was any change in it
	diff_mv_sync "${FROM_PERUN}" "${DST_FILE}"

	if [ $? -eq 0 ]; then
		log_msg I_CHANGED
		#if file have changed, reload aliases
		catch_error E_DOALIASES /etc/mail/doaliases -p
	else
		#if file have not changed, do nothing
		log_msg I_NOT_CHANGED
	fi
}
