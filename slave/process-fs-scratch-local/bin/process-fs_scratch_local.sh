#!/bin/bash

# List of logins who have to have directory in the /scratch
PROTOCOL_VERSION='3.3.0'


function process {
	FROM_PERUN="${WORK_DIR}/fs_scratch_local"
	SCRATCH_MOUNTPOINT=`cat ${WORK_DIR}/scratch_mountpoint`
	UMASK_FILE="${WORK_DIR}/umask"

	I_DIR_CREATED=(0 'Scratch directory ${SCRATCH_MOUNTPOINT}/${LOGIN} ($U_UID.$U_GID) for ${LOGIN} created.')

	E_CANNOT_CREATE_DIR=(50 'Cannot create directory ${SCRATCH_MOUNTPOINT}/${LOGIN}.')
	E_CANNOT_SET_OWNERSHIP=(51 'Cannot set ownership ${U_UID}.${U_GID} for directory ${SCRATCH_MOUNTPOINT}/${LOGIN}')
	E_CANNOT_SET_PERMISSIONS=(52 'Cannot set permissions 0755 for directory ${SCRATCH_MOUNTPOINT}/${LOGIN}.')
	E_SCRATCH_DIR_NOT_EXISTS=(53 'Scratch directory ${SCRATCH_MOUNTPOINT} does not exist.')

	create_lock

	if [ -z "${UMASK}" ]; then
		UMASK=0755   #default pemissions
		[ -f "$UMASK_FILE" ] && UMASK=`head -n 1 "$UMASK_FILE"`
	fi

	# Check if the top-level scratch dir exists
	if [ ! -d "${SCRATCH_MOUNTPOINT}" ]; then
		log_msg E_SCRATCH_DIR_NOT_EXISTS
	fi

	# lines contains login\tUID\tGID\t...
	while IFS=`echo -e "\t"` read LOGIN U_UID U_GID SOFT_QUOTA_DATA HARD_QUOTA_DATA SOFT_QUOTA_FILES HARD_QUOTA_FILES; do
		SCRATCH_DIR="${SCRATCH_MOUNTPOINT}/${LOGIN}"

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
