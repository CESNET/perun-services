#!/bin/bash
PROTOCOL_VERSION='3.1.0'

function process {

	DEFAULT_DIR="/var/spool/perun/kerberos_admin_principals"

	if [ -z "$DST_DIR" ]; then
		DST_DIR=$DEFAULT_DIR
	fi

	if [ ! -d "$DST_DIR" ]; then
		mkdir -p "$DST_DIR"
	fi

	# Copy `kerberos_admin_principals` file to destination directory
	cp -f "${WORK_DIR}/kerberos_admin_principals" "$DST_DIR"
}
