#! /bin/bash

#
# Manage HBase user namespaces in Hadoop environment
#
# In addition unix users and groups need to be managed on the whole Hadoop cluser.
#
# Where to launch:
# * on master node (or any node with HBase client and admin client keytab)
# * launch only once
#
# Requirements:
# * client admin Kerberos keytab (not required for unsecured cluster)
# * HBase client installed and configured
#
# Physical delete:
# * disabled by default (enable using FORCE_DELETE=1)
# * removes all the tables in user namespace and the namespace itself
#
# Last actions are stored in /var/tmp/perun-hadoop-hbase-*.sh.
#
# Usernames can't contain '-' character, they will by skipped.
#

PROTOCOL_VERSION='3.0.0'

function process() {
	FROM_PERUN="${WORK_DIR}/hadoop_hbase"

	FORCE_DELETE=${FORCE_DELETE:-'0'}
	KEYTAB=${KEYTAB:-'/etc/security/keytab/hbase.service.keytab'}
	PRINCIPAL=${PRINCIPAL:-"hbase/`hostname -f`@${REALM}"}
	RESERVED=${RESERVED:-'NAMESPACE|default|hbase|hive|oozie'}

	KRB5CCNAME="FILE:${WORK_DIR}/krb5cc_perun_hadoop_hbase"

	I_HBASE_CREATED=(0 'User ${login} will be created.')
	I_HBASE_DELETED=(0 'User ${login} will be deleted.')
	I_HBASE_OK=(0 'HBase shell OK.')
	I_HBASE_SIMULATED=(0 'Delete actions not performed.')
	E_KINIT_FAILED=(1 'Kinit on HBase master failed')
	E_HBASE_NAMESPACE_LIST=(2 'Cannot get list of namespaces')
	E_HBASE_TABLE_LIST=(3 'Cannot get list of tables from ${login}')
	E_HBASE_FAILED=(4 'HBase shell failed')
	E_EMPTY_LIST=(5 'The list is empty!')
	E_EMPTY_USERNAME=(6 'Empty username')

	create_lock
	chown hbase "${WORK_DIR}"

	# Kerberos ticket (only for secured cluster)
	if [ -n "$REALM" ]; then
		su hbase -s /bin/bash -p -c "kinit -k -t '${KEYTAB}' '${PRINCIPAL}'" || log_msg E_KINIT_FAILED
	fi

	# get list from HBase
	echo list_namespace | su hbase -s /bin/bash -p -c "hbase shell -n" >"${WORK_DIR}/out.txt" 2>/dev/null || log_msg E_HBASE_NAMESPACE_LIST
	head -n -3 "${WORK_DIR}/out.txt" | sort > "${WORK_DIR}/hbase-list.txt"

	# get list from Perun
	[ -s "${FROM_PERUN}" ] || log_msg E_EMPTY_LIST
	# HBase can't handle '-' in login names, blacklist all such users
	grep -v -- '-' "${FROM_PERUN}" | sort > "${WORK_DIR}/perun-list.txt"

	# compare and action
	rm -f "${WORK_DIR}/add.hbase" "${WORK_DIR}/del.hbase"
	diff "${WORK_DIR}/hbase-list.txt" "${WORK_DIR}/perun-list.txt" | while read op login; do
		case "$op" in
			'>')
				# add user
				[ -n "${login}" ] || log_msg E_EMPTY_USERNAME

				(echo "create_namespace '${login}'"
				 echo "grant '${login}', 'RWXCA', '@${login}'"
				 echo
				) >> "${WORK_DIR}/add.hbase"
				log_msg I_HBASE_CREATED
			;;
			'<')
				# delete user (no real delete for now)
				[ -n "${login}" ] || log_msg E_EMPTY_USERNAME

				if echo "${login}" | egrep -q "^${RESERVED}\$"; then
					continue
				fi

				# a) delete tables
				echo "list_namespace_tables '${login}'" | su hbase -s /bin/bash -p -c "hbase shell -n" 2>/dev/null > "${WORK_DIR}/out.txt" || log_msg E_HBASE_TABLE_LIST
				cat "${WORK_DIR}/out.txt" | awk '/^TABLE/ {o=1;next} /.*/ && o {print $0}' | head -n -3 > "${WORK_DIR}/hbase-user-tables.txt"
				while read table; do
					echo "disable '${table}'"
					echo "drop '${table}'"
				done < "${WORK_DIR}/hbase-user-tables.txt" >> "${WORK_DIR}/del.hbase"
				# b) delete user
				(echo "revoke '${login}', '@${login}'"
				 echo "revoke '${login}', 'C'"
				 echo "drop_namespace '${login}'"
				 echo
				) >> "${WORK_DIR}/del.hbase"
				log_msg I_HBASE_DELETED
			;;
		esac
	done

	if [ -s "${WORK_DIR}/add.hbase" ]; then
		cat "${WORK_DIR}/add.hbase" | su hbase -s /bin/bash -p -c "hbase shell -n" >/dev/null 2>&1 || log_msg E_HBASE_FAILED
		mv "${WORK_DIR}/add.hbase" /var/tmp/perun-hadoop-hbase-add.sh
		log_msg I_HBASE_OK
	fi
	if [ -s "${WORK_DIR}/del.hbase" ]; then
		if [ "$FORCE_DELETE" -eq 1 ]; then
			cat "${WORK_DIR}/del.hbase" | su hbase -s /bin/bash -p -c "hbase shell -n" >/dev/null 2>&1 || log_msg E_HBASE_FAILED
			log_msg I_HBASE_OK
		else
			log_msg I_HBASE_SIMULATED
		fi
		mv "${WORK_DIR}/del.hbase" /var/tmp/perun-hadoop-hbase-delete.sh
	fi

	if [ -n "$REALM" ]; then
		su hbase -s /bin/bash -p -c 'kdestroy'
	fi
}
