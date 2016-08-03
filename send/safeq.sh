#!/bin/bash

# Original update script created by (C) funny from ZCU
# 2007-08-05 handle bug in ldapsearch
# 2011-08-10 generification of script
# 2013-06-20 prevent concurrent run

PROTOCOL_VERSION='3.0.0'

	# sort & diff scripts from CPAN
	LDIFDIFF="/home/slava/perun-services/slave/ldap/ldifdiff.pl"
	LDIFSORT="/home/slava/perun-services/slave/ldap/ldifsort.pl"

	# work files location
	INFILE="$1"
	OLD_FILE="$2"

	# sorted work files
	SINFILE="/tmp/sorted-safeq.ldif"
	S_OLD_FILE="/tmp/sorted-safeq-old.ldif"

	# diff file used to modify ldap
	#MODFILE="${WORK_DIR}/mod"


	if test -s "$OLD_FILE"; then
	# LDAP is not empty under base DN

		# SORT LDIFs
		$LDIFSORT -k dn $OLD_FILE >$S_OLD_FILE
		$LDIFSORT -k dn $INFILE >$SINFILE

		# DIFF LDIFs
		$LDIFDIFF -k dn $SINFILE $S_OLD_FILE | sed '1,1{/^$/d; }; /^[^ ].*/N; s/\n //g' 

		# Update LDAP based on changes
		#ldapmodify -x -H "$LDAP_URL" -D "$LDAP_LOGIN" -w "$LDAP_PASSWORD" -c < MODFILE

	else
	# LDAP is empty under base DN

		#$LDIFSORT -k dn $INFILE >$SINFILE
		$LDIFSORT -k dn $INFILE >$SINFILE

		$LDIFDIFF -k dn $SINFILE /dev/null | sed '/^[^ ].*/N; s/\n //g' 

		# All entries are new, use ldapadd
		#ldapadd -x -H "$LDAP_URL" -D "$LDAP_LOGIN" -w "$LDAP_PASSWORD" -c < $SINFILE

	fi

