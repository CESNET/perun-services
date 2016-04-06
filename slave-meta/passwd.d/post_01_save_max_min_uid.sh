#!/bin/sh

MIN_PERUN_UID=`head -n 1 "${WORK_DIR}/min_uid"`
MAX_PERUN_UID=`head -n 1 "${WORK_DIR}/max_uid"`

echo -e "MIN_UID=${MIN_PERUN_UID}\nMAX_UID=${MAX_PERUN_UID}" > /etc/passwd.uid
