#!/bin/bash

PROTOCOL_VERSION='3.0.0'

function process {

	# check if access token has been obtained by pre_ script
	if [ -z "$ACCESS_TOKEN" ]
	then
		echo "Missing access token for o365 service."
	  	exit 0;
	fi

	FILE_PHOTOS="photos.csv"
	FILE_USERS="users.json"

	E_USERS_SYNC=(50 'Error during users synchronization')

	create_lock

	catch_error E_USERS_SYNC ./process-o365-perl
}
