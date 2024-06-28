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

	# Check if list from perun is not empty
	if [[ ! -f $DST_DIR/kerberos_admin_principals || $(wc -l <$DST_DIR/kerberos_admin_principals) -eq 0 ]]; then
		exit 1
	fi

	# Delete kerberos principal from database that are not in perun group
	for x in `grep -wvFf $DST_DIR/kerberos_admin_principals <<< $(kadmin.heimdal -l -r ADMIN.META get -o principal "*" | grep -v "/\|default" | grep "^." | awk -F " " '{print$2}' | sort) | awk -F "@" '{print$1}'`; do kadmin.heimdal -l -r ADMIN.META del $x; done
}
