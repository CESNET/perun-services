#!/bin/bash

PROTOCOL_VERSION='3.1.0'

function process {

	FROM_PERUN_DIR="${WORK_DIR}/mailinglists/"

	I_MAILING_LIST_UPDATED=(0 '${MAILING_LIST_NAME} successfully updated.')

	create_lock

	for MAILING_LIST_NAME in `ls $FROM_PERUN_DIR/` ; do
			# set list members
			cat "${FROM_PERUN_DIR}/${MAILING_LIST_NAME}" | grep -v "^#" | sudo /usr/lib/mailman/bin/sync_members --welcome-msg=no --goodbye-msg=no -f - $MAILING_LIST_NAME
			log_msg I_MAILING_LIST_UPDATED
	done

}
