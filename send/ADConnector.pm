package ADConnector;
use Exporter 'import';
@ISA = ('Exporter');
@EXPORT = qw(init_config resolve_pdc ldap_connect ldap_bind ldap_unbind ldap_log load_perun load_ad load_group_members);

use strict;
use warnings;

=pod

=encoding UTF-8

=head1 AD connector library for Perun

This library provides shared functions for Perun send scripts to manage users and groups in Active Directory.

=head1 SYNOPSIS

	use ADConnector;

	my @credentials = ADConnector::init_config("namespace");
	my $ad_location = ADConnector::resolve_pdc($credentials[0]);
	my $ad = ADConnector::ldap_connect($ad_location);
	ADConnector::ldap_bind($ad, $credentials[1], $credentials[2]);

	my @perun_entries = load_perun("ldif_path")
	my @ad_entries = load_ad($ad, "base_dn", $filter, @attrs);

	.... your processing ....

	ADConnector::ldap_unbind($ad);

=head1 METHODS

=head2 init_config()

Return URL and credentials for specified namespace. Data are read from C</etc/perun/namespace.ad> file.

=head2 resolve_pdc()

Resolve primary domain controller from domain URL. Expected format of parameter is C<protocol://host:port>. Result is URL in same format.

=head2 ldap_connect()

Connects to AD. Connection (Net::LDAP) object is returned. You should pass only URL to Primary Domain Controller (PDC) otherwise you can encounter race-conditions.

=head2 ldap_bind()

Bind to AD using Net::LDAP connection, username and password params.

=head2 ldap_unbind()

Unbind from AD if connected (binded) by Net::LDAP.

=head2 load_perun()

Load data from LDIF file from Perun and return it as array of Net::LDAP::Entry.

=head2 load_ad()

Load data from AD and return them as array of Net::LDAP::Entry. Expected params are connection (Net::LDAP object), string base DN for search, string filter and array of attribute names to retrieve with each entry.

=head2 load_group_members()

Load members of a group from AD. (when it has more than 1500 items). Takes Net:LDAP connection, string base DN and search filter.

=head2 ldap_log()

Log message to file. Takes service name and message string params.

=head1 AUTHOR

Pavel Zlámal - <zlamal@cesnet.cz>

=cut

use Net::LDAPS;
use Net::LDAP::Entry;
use Net::LDAP::Message;
use Net::LDAP::LDIF;
use Net::LDAP::Control::Paged;
use Net::LDAP::Constant qw( LDAP_CONTROL_PAGED );

#
# Load username and password for selected namespace and return it as a array
#
sub init_config($) {

	# load namespace
	my $namespace = shift;

	# check if config file for namespace exists
	my $filename = "/etc/perun/".$namespace.".ad";
	unless (-e $filename) {
		ldap_log('ad_connection', "Configuration file for namespace \"" . $namespace . "\" doesn't exist!");
		exit 2; # login-namespace is not supported
	}

	# load configuration file
	open FILE, "<" . $filename;
	my @lines = <FILE>;
	close FILE;

	# remove new-line characters from the end of lines
	chomp @lines;

	my @credentials = ();
	push(@credentials, $lines[0]);
	push(@credentials, $lines[1]);
	push(@credentials, $lines[2]);
	return @credentials;

}

#
# Resolve primary domain controller from URL
#
sub resolve_pdc($) {

	my $ldap_location = shift;
	my ($protocol, $host, $port);
	if($ldap_location =~ /^([^\/]+:\/\/)?([^:]+):([0-9]+)$/) {
		($protocol, $host, $port) = ($1, $2, $3);
	} else {
		ldap_log('ad_connection', "[AD] Ldap location in wrong format. Expected: protocol://host:port");
		exit 1;
	}
	#Connect to primary domain controller
	my $pdc_host = `host -t SRV _ldap._tcp.pdc._msdcs.$host`;
	unless(defined $pdc_host) {
		ldap_log('ad_connection', "[AD] Cannot get PDC host name. DNS query for SRV record returned $?");
		exit 1;
	}
	chomp $pdc_host;
	unless($pdc_host =~ s/^.* (.*).$/$1/) {
		ldap_log('ad_connection', "[AD] Cannot get PDC host name. Returned $pdc_host");
		exit 1;
	}

	return $protocol . $pdc_host . ":" . $port;

}

#
# Connects to AD. You should pass only URL to Primary Domain Controller (PDC).
# See resolve_pdc() function.
#
sub ldap_connect($) {

	my $ldap_location = shift;

	# LDAP connect
	my $ldap = Net::LDAPS->new( "$ldap_location" , onerror => 'warn' , timeout => 15);

	return $ldap;

}

#
# Bind to AD using connection, username and password params
#
sub ldap_bind($$$) {

	my $ldap = shift;
	my $ldap_user = shift;
	my $ldap_pass = shift;

	# LDAP log-in
	if ($ldap) {
		$ldap->bind( "$ldap_user" , password => "$ldap_pass" );
		ldap_log('ad_connection', "[AD] connected as: $ldap_user");
	} else {
		ldap_log('ad_connection', "[AD] can't connect to AD.");
		exit 1;
	}

}

#
# Disconnect from LDAP connection if connected
#
sub ldap_unbind($) {

	my $ldap = shift;

	if ($ldap) {
		$ldap->unbind;
		ldap_log('ad_connection', "[AD] disconnected.");
	} else {
		ldap_log('ad_connection', "[AD] can't disconnect from AD (connection not exists).");
	}

}

#
# Log any message to log file located in same folder as the script.
# Each message starts at new line with a date.
#
# $service Name of service
# $message Message to log
#
sub ldap_log($$) {

	my $service = shift;
	my $message = shift;

	open(LOGFILE, ">>./" . $service . ".log");
	print LOGFILE (localtime(time) . ": " . $message . "\n");
	close(LOGFILE);

}

#
# Load data from ldif file from Perun and return it as array of Net::LDAP::Entry
#
sub load_perun($){

	my $ldif_path = shift;

	my @perun_entries = ();

	# load users
	my $ldif = Net::LDAP::LDIF->new( $ldif_path, "r", onerror => 'warn');

	while( not $ldif->eof ( ) ) {
		my $entry = $ldif->read_entry();
		if ( $ldif->error() ) {
			ldap_log('ad_connection', "Error read Perun ldif:  " . $entry->get_value('cn') . " | " . $ldif->error());
		} else {
			# push valid entry
			push(@perun_entries, $entry) if ($entry->get_value('cn'));
		}
	}

	return @perun_entries;

}

#
# Load data from AD and return them as array of Net::LDAP::Entry
#
# $ldap connection
# $base_dn DN of search base
# $filter Search filter
# @attrs attributes to retrieve with each entry
#
sub load_ad($$$$) {

	my $ldap = shift;
	my $base_dn = shift;
	my $filter = shift;
	my @attrs = shift;

	my @ad_entries = ();

	# load users
	my $page = Net::LDAP::Control::Paged->new(size => 9999);
	my $mesg;
	my $cookie;

	while (1) {

		$mesg = $ldap->search( base => $base_dn ,
			scope => 'sub' ,
			filter => $filter ,
			attrs => @attrs ,
			control => [$page]
		);

		$mesg->code && die "Error on search: $@ : " . $mesg->error;
		ldap_log('ad_connection', "Processing page with " . $mesg->count() . " entries.");

		for my $entry ($mesg->entries) {
			# store only valid entry from AD
			push(@ad_entries,$entry) if ($entry->get_value('cn'));
		}

		# Paging Control
		my ($resp) = $mesg->control(LDAP_CONTROL_PAGED) or last;
		$cookie = $resp->cookie or last;
		$page->cookie($cookie);

	}

	return @ad_entries;

}

#
# Load group members from AD (when it has more than 1500 items)
#
# $ldap connection
# $base_dn DN of search base
# $filter Search filter
#
sub load_group_members($$$) {

	my $ldap = shift;
	my $base = shift;
	my $filter = shift;

	my $mesg;
	my @members = ();
	my $index = 0;

	while ($index ne '*') {
		$mesg = $ldap->search( base => $base, filter => $filter,
			scope => 'base', attrs => [ ($index > 0) ? "member;range=$index-*" : 'member' ]
		);
		# if success
		if ($mesg->code == 0) {
			my $entry = $mesg->entry(0);
			my $attr;

			# large group: let's do the range option dance
			if (($attr) = grep(/^member;range=/, $entry->attributes)) {
				push(@members, $entry->get_value($attr));
				if ($attr =~ /^member;range=\d+-(.*)$/) {
					$index = $1;
					$index++  if ($index ne '*');
				}
			} else {
				# small group: no need for the range dance
				@members = $entry->get_value('member');
				last;
			}
		} else {
			# failure
			last;
		}
	}

	if ($mesg->code == 0) {
		# success: @members contains the members of the group
		return @members;
	} else {
		# failure: deal with the error in $mesg
		return $mesg->code();
	}

}