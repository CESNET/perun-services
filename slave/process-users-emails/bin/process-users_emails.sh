#!/bin/bash

PROTOCOL_VERSION='3.0.0'

function process {

	DST_DIR="/tmp/"
  DST_FILE="users_emails"
	FROM_PERUN="${WORK_DIR}/users_emails"

	### Status codes
	I_CHANGED=(0 "${DST_FILE} file updated")
	E_CANNOT_COPY=(50 "Cannot copy file ${FROM_PERUN} to ${DST_DIR}/${DST_FILE}")

	create_lock

	cp "${FROM_PERUN}" "${DST_DIR}/${DST_FILE}"

	if [ $? -eq 0 ]; then
		log_msg I_CHANGED
	else
		log_msg E_CANNOT_COPY
	fi
}
