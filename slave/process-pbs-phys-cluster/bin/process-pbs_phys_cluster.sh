#!/bin/bash

PROTOCOL_VERSION='3.1.0'


function process {
	E_UNKNOWN_PBS=(51 'Unsupported PBS type')

	DST_FILE="/var/local/perun-pbs/pbs_phys_cluster"
	if [ -f /var/spool/torque/server_name ]; then
		_PBS_SERVER=`cat /var/spool/torque/server_name`
	elif [ -f /etc/default/pbs_licenses ]; then
		. /etc/default/pbs_licenses
		_PBS_SERVER=$SERVER_NAME
	else
		log_msg E_UNKNOWN_PBS
	fi

	### Status codes
	I_CHANGED=(0 "${DST_FILE} updated")
	I_NOT_CHANGED=(0 "${DST_FILE} has not changed")
	E_PBS_SERVER_VAR=(50 'PBS_SERVER variable is not set')

	OLD="${DST_FILE}.old.perun"
	FROM_PERUN="${WORK_DIR}/pbs_phys_cluster"

	create_lock

	# PBS_SERVER can be also set in pbs_phys_cluster.d/pre_00_set_pbs_server
	[ -z $PBS_SERVER ] && PBS_SERVER=$_PBS_SERVER
	catch_error E_PBS_SERVER_VAR test "$PBS_SERVER"

	# Iterate through all entries from the perun refresh add current host records in the cache
	while IFS=`echo -e ":"` read HOST CLUSTER; do
		/usr/sbin/update_cache "${PBS_SERVER}" "${HOST}" phys_cluster "${CLUSTER}"
	done < "${FROM_PERUN}"
	# do not delete anything for now
}
