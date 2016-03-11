#!/bin/sh

# Sort entries by realms, @META first then @EINFRA

PASSWD_FROM_PERUN="${WORK_DIR}/passwd_nfs4"

TMP_FILE=`mktemp`

grep "@META" $PASSWD_FROM_PERUN > $TMP_FILE
grep -v "@META" $PASSWD_FROM_PERUN >> $TMP_FILE

# Overwrite ogirinal file with sorted one
cat $TMP_FILE > $PASSWD_FROM_PERUN

rm -f $TMP_FILE
