#!/bin/bash

# List of logins who have to have directory in the /home
PROTOCOL_VERSION='3.7.0'

function process {
	FROM_PERUN="${WORK_DIR}/fs_home"
	UMASK_FILE="${WORK_DIR}/umask"
	QUOTAS_FILE="${WORK_DIR}/quotas"
	QUOTA_ENABLED_FILE="${WORK_DIR}/quota_enabled"

	I_DIR_CREATED=(0 'Home directory ${HOME_DIR} ($U_UID.$U_GID) created.')

	E_CANNOT_SET_OWNERSHIP=(51 'Cannot set ownership ${U_UID}.${U_GID} for directory ${TMP_DIR}.')
	E_CANNOT_SET_PERMISSIONS=(52 'Cannot set permissions ${UMASK} for directory ${TMP_DIR}.')
	E_CANNOT_SET_QUOTA=(54 'Cannot set quota on ${QUOTA_FS} for user ${U_UID}')
	E_CANNOT_COPY_SKEL=(55 'Cannot copy skel directory ${SKEL_DIR} to ${TMP_HOME_DIR}')
	E_BAD_HOME_OWNER=(56 'Home directory ${HOME_DIR} for user ${U_UID} has bad owner')
	E_CANNOT_CREATE_TMP_HOME_DIR=(57 'Cannot create temporary home directory ${TMP_HOME_DIR}')

	E_CANNOT_CREATE_TEMP=(57 'Cannot create temp directory ${TMP_DIR}.')
	E_CANNOT_MOVE_TEMP=(58 'Cannot move ${TMP_DIR} to ${HOME_DIR}.')

	create_lock

	UMASK=0755   #default pemissions
	[ -f "$UMASK_FILE" ] && UMASK=`head -n 1 "$UMASK_FILE"`

	#if QUOTA_ENABLED is not set in prescript, try to get info from quota_enabled file
	#if file not exists, set quota_enabled to 0 (false) (for backwards compatibility)
	if [ -z "${QUOTA_ENABLED}" ]; then
		if [ -f "$QUOTA_ENABLED_FILE}" ]; then
			QUOTA_ENABLED=`head -n 1 "$QUOTA_ENABLED_FILE"`
		else
			QUOTA_ENABLED=0
		fi
	fi

	if [ "${QUOTA_ENABLED}" -gt 0 ]; then
		if [ ! -z "${SET_QUOTA_PROGRAM}" ]; then
			if [ -x "${SET_QUOTA_PROGRAM}" ]; then
				SET_QUOTA="${SET_QUOTA_PROGRAM}"
				QUOTA_ENABLED=1
			else
				echo "Can't set user quotas! ${SET_QUOTA_PROGRAM} is not executable" 1>&2
				QUOTA_ENABLED=0
			fi
		else
			if [ -x /usr/sbin/setquota ]; then
				SET_QUOTA=/usr/sbin/setquota
				#setquota name block-softlimit block-hardlimit inode-softlimit inode-hardlimit filesystem
				SET_QUOTA_TEMPLATE='$U_UID $SOFT_QUOTA_DATA $HARD_QUOTA_DATA $SOFT_QUOTA_FILES $HARD_QUOTA_FILES $QUOTA_FS'
				QUOTA_ENABLED=1
			else
				echo "Can't set user quotas! /usr/sbin/setquota is not available" 1>&2
				QUOTA_ENABLED=0
			fi
		fi
	fi

	SKEL_DIR=
	#find first path from $PERUN_SKEL_PATH which exists and is a directory
	if [ -n "$PERUN_SKEL_PATH" ]; then
		IFS=':' read -ra DIRS <<< "$PERUN_SKEL_PATH"
		for DIR in "${DIRS[@]}"; do
			if [ -d "$DIR" ]; then
				SKEL_DIR="$DIR"
				break;
			fi
		done
	fi

	TMP_DIR_BASIC_NAME='tmp-perun-fs_home-'
	# lines contains homeMountPoint\tlogin\tUID\tGID\t...
	# create home directories
	while IFS=`echo -e "\t"` read U_HOME_MNT_POINT U_LOGNAME U_UID U_GID USER_STATUS USER_GROUPS REST_OF_LINE; do
		HOME_DIR="${U_HOME_MNT_POINT}/${U_LOGNAME}"

		run_mid_hooks

		if [ ! -d "${HOME_DIR}" ]; then

			TMP_DIR=`mktemp -d --tmpdir="${U_HOME_MNT_POINT}" "${TMP_DIR_BASIC_NAME}${U_LOGNAME}.XXXX"`
			if [ "$?" -ne 0 ]; then
				log_msg  E_CANNOT_CREATE_TEMP
			fi
			#set this temp directory for remove when script ends (if still exists)
			add_on_exit "rm -rf ${TMP_DIR}"
			TMP_HOME_DIR="${TMP_DIR}/${U_LOGNAME}"

			if [ -n "$SKEL_DIR" ]; then
				catch_error E_CANNOT_COPY_SKEL cp -ar "$SKEL_DIR" "$TMP_HOME_DIR"
			else
				catch_error E_CANNOT_CREATE_TMP_HOME_DIR mkdir "$TMP_HOME_DIR"
			fi

			catch_error E_CANNOT_SET_OWNERSHIP chown -R "${U_UID}":"${U_GID}" "${TMP_HOME_DIR}"
			catch_error E_CANNOT_SET_PERMISSIONS chmod "$UMASK" "${TMP_HOME_DIR}"

			catch_error E_CANNOT_MOVE_TEMP mv "${TMP_HOME_DIR}" "${HOME_DIR}"

			log_msg I_DIR_CREATED
		else
			catch_error E_BAD_HOME_OWNER [ `stat -L -c "%u" ${HOME_DIR}` -eq ${U_UID} ]
		fi
	done < "${FROM_PERUN}"

	# set quotas
	while IFS=`echo -e "\t"` read U_UID QUOTA_FS SOFT_QUOTA_DATA HARD_QUOTA_DATA SOFT_QUOTA_FILES HARD_QUOTA_FILES REST_OF_LINE; do
		if [ "$QUOTA_ENABLED" -gt 0 ]; then
			SET_QUOTA_PARAMS=`eval echo $SET_QUOTA_TEMPLATE`
			catch_error E_CANNOT_SET_QUOTA $SET_QUOTA $SET_QUOTA_PARAMS
		fi
	done < "${QUOTAS_FILE}"
}
