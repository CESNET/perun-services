#!/bin/bash

PROTOCOL_VERSION='3.1.0'

function process {
  FROM_PERUN_DIR="${WORK_DIR}/mailinglists/"
  EXISTING_MAILING_LISTS="/etc/perun/services/mailman_mu/existing_mailinglists"

  I_MAILING_LIST_IS_NOT_MANAGED_BY_PERUN=(0 '${MAILING_LIST_NAME} is not managed by Perun.')
  I_MAILING_LIST_UPDATED=(0 '${MAILING_LIST_NAME} successfully updated.')

  create_lock

  for MAILING_LIST_FILE_NAME in $FROM_PERUN_DIR/* ; do
    [[ -e "$MAILING_LIST_FILE_NAME" ]] || break # skip if no files present
    MAILING_LIST_NAME=$(basename "$MAILING_LIST_FILE_NAME")

    # check if the mailing lists is managed by perun
    if [ `grep -c "^${MAILING_LIST_NAME} " ${EXISTING_MAILING_LISTS}` -eq 1 ]; then
      # extract the mailman mailing list name from $EXISTING_MAILING_LISTS
      MAILMAN_MAILING_LIST_NAME=`grep "^${MAILING_LIST_NAME}" ${EXISTING_MAILING_LISTS} | awk '{ print $2; }'`

      # set list members
      cat "${FROM_PERUN_DIR}/${MAILING_LIST_NAME}" | grep -v "^#" | sudo /usr/local/mailman/bin/sync_members --welcome-msg=no --goodbye-msg=no -f - $MAILMAN_MAILING_LIST_NAME
      log_msg I_MAILING_LIST_UPDATED
    else
      log_msg I_MAILING_LIST_IS_NOT_MANAGED_BY_PERUN
    fi
  done
}
