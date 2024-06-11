#!/bin/bash

PROTOCOL_VERSION='3.0.0'


function process {
  FROM_PERUN="${WORK_DIR}/fs_scratchdirs"

  I_DIR_CREATED=(0 'Scratch directory ${SCRATCH_DIR} ($U_UID.$U_GID) for ${U_LOGNAME} created.')

  E_CANNOT_CREATE_DIR=(50 'Cannot create directory ${SCRATCH_DIR}/${LOGIN}.')
  E_CANNOT_SET_OWNERSHIP=(51 'Cannot set ownership ${U_UID}.${U_GID} for directory ${SCRATCH_DIR}')
  E_CANNOT_SET_PERMISSIONS=(52 'Cannot set permissions ${UMASK} for directory ${SCRATCH_DIR}.')
  E_SCRATCH_DIR_NOT_EXISTS=(53 'Scratch directory ${U_SCRATCH_MNT_POINT} does not exist.')

  create_lock

  # lines contains MOUNT_POINT\tlogin\tUID\tGID\tSTATUS\tUMASK
  while IFS=`echo -e "\t"` read U_SCRATCH_MNT_POINT U_LOGNAME U_UID U_GID USER_STATUS UMASK; do

    # Handle only valid users
    if [ "${USER_STATUS}" != "VALID" ]; then
      continue
    fi

    # Check if the top-level scratch dir exists
    if [ ! -d "${U_SCRATCH_MNT_POINT}" ]; then
      log_msg E_SCRATCH_DIR_NOT_EXISTS
    fi

    SCRATCH_DIR="${U_SCRATCH_MNT_POINT}/${U_LOGNAME}"

    if [ ! -d "${SCRATCH_DIR}" ]; then
      catch_error E_CANNOT_CREATE_DIR  mkdir "${SCRATCH_DIR}"
      log_msg I_DIR_CREATED
    fi

    if [ "`stat -L -c '%u:%g' ${SCRATCH_DIR}`" != "${U_UID}:${U_GID}" ]; then
      catch_error E_CANNOT_SET_OWNERSHIP chown ${U_UID}:${U_GID} "${SCRATCH_DIR}"
      log_debug "Ownership of ${SCRATCH_DIR} was set to ${U_UID}:${U_GID}"
    fi

    if [ "`stat -L -c '%a' ${SCRATCH_DIR}`" != "${UMASK}" ]; then
      catch_error E_CANNOT_SET_PERMISSIONS chmod "${UMASK}" "${SCRATCH_DIR}"
      log_debug "Permissions on ${SCRATCH_DIR} were set to ${UMASK}"
    fi

  done < "${FROM_PERUN}"
}