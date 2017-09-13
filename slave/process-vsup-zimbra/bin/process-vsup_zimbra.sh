#!/bin/bash

# Script for managing users in Zimbra mail server

PROTOCOL_VERSION='3.0.0'

function process {

	EXECSCRIPT="${LIB_DIR}/${SERVICE}/process-vsup_zimbra.pl"

	create_lock

	FROM_PERUN="${WORK_DIR}/vsup_zimbra.csv"
	IGNORED="${WORK_DIR}/vsup_zimbra_ignored_accounts"

	perl $EXECSCRIPT $FROM_PERUN $IGNORED

	exit $?
}
