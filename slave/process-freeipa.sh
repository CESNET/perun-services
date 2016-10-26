#!/bin/bash
PROTOCOL_VERSION='3.0.0'


function process {

	FROM_PERUN="${WORK_DIR}/freeipa"
	EXEC_SCRIPT="${SCRIPTS_DIR}/freeipa/process-freeipa.py"

	create_lock
	
	python2 $EXEC_SCRIPT --perun-file $FROM_PERUN --user $USER --password $PASSWORD --host-url $IPA_HOST
	
	exit $?
	
}
