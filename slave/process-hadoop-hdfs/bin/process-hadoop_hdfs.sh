#! /bin/bash

#
# Manage user home directories at Hadoop filesystem
#
# In addition unix users and groups need to be managed on the whole Hadoop cluser.
#
# Where to lauch:
# * on master node (or any node with HDFS client and admin client keytab)
# * launch only once
#
# Requirements:
# * client admin Kerberos keytab (not required for unsecured cluster)
# * HDFS client installed and configured
#
# Physical delete:
# * disabled by default (enable using FORCE_DELETE=1)
# * removes /user/${login}
# * manual cleanups are needed:
#  * other user owned files are not deleted
#  * remaining ACLs are not removed
#  * see /var/tmp/perun-hadoop-hdfs-deleted.txt
#

PROTOCOL_VERSION='3.0.0'

function process() {
	FROM_PERUN="${WORK_DIR}/hadoop_hdfs"

	FORCE_DELETE=${FORCE_DELETE:-'0'}
	KEYTAB=${KEYTAB:-'/etc/security/keytab/nn.service.keytab'}
	PRINCIPAL=${PRINCIPAL:-"nn/`hostname -f`@${REALM}"}
	RESERVED=${RESERVED:-'hbase|hdfs|hive|oozie|spark'}

	KRB5CCNAME="FILE:${WORK_DIR}/krb5cc_perun_hadoop_hdfs"

	I_HDFS_CREATED=(0 'Directory /user/${login} created.')
	I_HDFS_DELETED=(0 'Directory /user/${login} deleted.')
	E_KINIT_FAILED=(1 'Kinit failed')
	E_HDFS_DELETE_FAILED=(2 'Deleting /user/${login} failed')
	E_HDFS_LIST_FAILED=(2 'Cannot get list of directories from HDFS')
	E_HDFS_MKDIR_FAILED=(2 'Cannot create directory /user/${login}')
	E_HDFS_PERMS_FAILED=(2 'Cannot set permissions on /user/${login}')
	E_EMPTY_LIST=(3 'The list is empty!')
	E_EMPTY_USERNAME=(4 'Empty username')

	create_lock
	chown hdfs "${WORK_DIR}"

	# Kerberos ticket (only for secured cluster)
	if [ -n "$REALM" ]; then
		su hdfs -s /bin/bash -p -c "kinit -k -t '${KEYTAB}' '${PRINCIPAL}'" || log_msg E_KINIT_FAILED
	fi

	# get list from Hadoop HDFS
	su hdfs -s /bin/bash -p -c "hdfs dfs -ls /user" >"${WORK_DIR}/hdfs-dirs.txt" || log_msg E_HDFS_LIST_FAILED
	tail -n +2 "${WORK_DIR}/hdfs-dirs.txt" | sed 's,.* /user/,,' | sort > "${WORK_DIR}/hdfs-list.txt"

	# get list from Perun
	[ -s "${FROM_PERUN}" ] || log_msg E_EMPTY_LIST
	sort "${FROM_PERUN}" > "${WORK_DIR}/perun-list.txt"

	# compare and action
	rm -f /var/tmp/perun-hdfs-delete.sh
	diff "${WORK_DIR}/hdfs-list.txt" "${WORK_DIR}/perun-list.txt" | while read op login; do
		case "$op" in
			'>')
				# add user
				[ -n "${login}" ] || log_msg E_EMPTY_USERNAME
				su hdfs -s /bin/bash -p -c "hdfs dfs -mkdir '/user/${login}'" || log_msg E_HDFS_MKDIR_FAILED
				su hdfs -s /bin/bash -p -c "hdfs dfs -chown '${login}:hadoop' '/user/${login}'" || log_msg E_HDFS_PERMS_FAILED
				su hdfs -s /bin/bash -p -c "hdfs dfs -chmod 0750 '/user/${login}'" || log_msg E_HDFS_PERMS_FAILED
				log_msg I_HDFS_CREATED
			;;
			'<')
				# delete user
				[ -n "${login}" ] || log_msg E_EMPTY_USERNAME
				if echo "${login}" | egrep -q "^${RESERVED}\$"; then
					continue
				fi
				if [ "$FORCE_DELETE" -eq 1 ]; then
					su hdfs -s /bin/bash -p -c "hdfs dfs -rm -r '/user/${login}'" || log_msg E_HDFS_DELETE_FAILED
					echo "`date -Is` ${login}" >> /var/tmp/perun-hadoop-hdfs-deleted.txt
					log_msg I_HDFS_DELETED
				else
					echo "su hdfs -s /bin/bash -p -c \"hdfs dfs -rm -r '/user/${login}'\"" >> /var/tmp/perun-hadoop-hdfs-delete.sh
				fi
			;;
		esac
	done

	if [ -n "$REALM" ]; then
		su hdfs -s /bin/bash -p -c 'kdestroy'
	fi
}
