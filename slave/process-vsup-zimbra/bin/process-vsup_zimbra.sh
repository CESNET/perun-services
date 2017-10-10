#!/bin/bash

# Script for managing users in Zimbra mail server

PROTOCOL_VERSION='3.0.0'

function process {

	EXECSCRIPT="${LIB_DIR}/${SERVICE}/process-vsup_zimbra.pl"

	create_lock

	FROM_PERUN="${WORK_DIR}/vsup_zimbra.csv"
	IGNORED="${WORK_DIR}/vsup_zimbra_ignored_accounts"

	# support czech chars in Zimbra values, since Zimbra has and perun exports the "C"
	export LANG=cs_CZ.UTF-8

	perl $EXECSCRIPT $FROM_PERUN $IGNORED

	exit $?
}
