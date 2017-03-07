#!/bin/bash

PROTOCOL_VERSION='3.0.0'

function process {

	# check if access token has been obtained by pre_ script
	if [ -z "$ACCESS_TOKEN" ]
	then
		echo "Missing access token for o365 service."
	  	exit 0;
	fi

	FILE_PHOTOS="${WORK_DIR}/photos.csv"
	FILE_USERS="${WORK_DIR}/users.json"

	E_USERS_SYNC=(50 'Error during users synchronization')

	EXECSCRIPT="${LIB_DIR}/${SERVICE}/process-o365.pl"

	create_lock

	catch_error E_USERS_SYNC $EXECSCRIPT
}
