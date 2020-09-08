package ADConnector;
use Exporter 'import';
@ISA = ('Exporter');
@EXPORT = qw(init_config resolve_domain_controlers ldap_connect_multiple_options resolve_pdc ldap_connect ldap_bind ldap_unbind ldap_log load_perun load_ad load_group_members compare_entry enable_uac disable_uac is_uac_enabled clone_entry_with_specific_attributes);

use strict;
use warnings;
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

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

=head2 resolve_domain_controlers()

Return a list of available domain controlers from a domain URL. Expected format of parameter is C<protocol://host:port>. Result is a list of URLs in the same format.

=head2 ldap_connect_multiple_options()

Connect to the AD through the first possible controler from a list of controlers. Connection (Net::LDAP) object is returned.

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

=head2 compare_entry()

Takes two entries and compares specified attribute. Return 1 if attr value differs (hence entry should be updated in AD).

=head2 ldap_log()

Log message to file. Takes service name and message string params.

=head2 clone_entry_with_specific_attributes()

Create clone of an existing ldap entry with specified attributes.

=head1 AUTHOR

Pavel Zlámal - <zlamal@cesnet.cz>

=cut

use Net::DNS::Resolver;
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
		print STDERR "Configuration file for namespace \"" . $namespace . "\" doesn't exist!";
		die "Configuration file for namespace \"" . $namespace . "\" doesn't exist!"; # login-namespace is not supported
	}

	# load configuration file
	open FILE, "<" . $filename || die "Can't open configuration file for namespace '$namespace'.";
	my @lines = <FILE>;
	close FILE || die "Can't close configuration file for namespace '$namespace'.";

	# remove new-line characters from the end of lines
	chomp @lines;

	my @credentials = ();
	push(@credentials, $lines[0]);
	push(@credentials, $lines[1]);
	push(@credentials, $lines[2]);
	return @credentials;

}

#
# Resolve available domain controlers from a URL
#
sub resolve_domain_controlers($) {
	my $ldap_location = shift;
	my ($protocol, $host, $port);
	if ($ldap_location =~ /^([^\/]+:\/\/)?([^:]+):([0-9]+)$/) {
		($protocol, $host, $port) = ($1, $2, $3);
	} else {
		ldap_log('ad_connection', "[AD] Ldap location in wrong format. Expected: protocol://host:port");
		die "[AD] Ldap location in wrong format. Expected: protocol://host:port";
	}
	my $resolver = Net::DNS::Resolver->new;
	my $query = $resolver->search($host);
	my @controlers = ();

	if ($query) {
		foreach ($query->answer) {
			next unless $_->type eq "A";
			push(@controlers, $protocol . $_->address . ":" . $port);
		}
	} else {
		my $error = $resolver->errorstring();
		ldap_log('ad_connection', "[AD] No answer was found for $host. DNS query returned error message: $error");
		die "[AD] No answer was found for $host. DNS query returned error message: $error";
	}
	if (!@controlers) {
		ldap_log('ad_connection', "[AD] DNS query for $host did not return any controler.");
		die "[AD] DNS query for $host did not return any controler.";
	}
	return @controlers;
}

#
# Connect to a controler from a list of controlers
#
sub ldap_connect_multiple_options($) {
	my $controlers = shift;
	my $ldap;

	foreach (@$controlers) {
		$ldap = Net::LDAPS->new( "$_" , onerror => 'warn' , timeout => 15);
		last if $ldap;
	}

	return $ldap;
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
		print STDERR "[AD] Ldap location in wrong format. Expected: protocol://host:port";
		die "[AD] Ldap location in wrong format. Expected: protocol://host:port";
	}
	#Connect to primary domain controller
	my $pdc_host = `host -t SRV _ldap._tcp.pdc._msdcs.$host`;
	unless(defined $pdc_host) {
		my $code = $?;
		ldap_log('ad_connection', "[AD] Cannot get PDC host name. DNS query for SRV record returned $code");
		print STDERR "[AD] Cannot get PDC host name. DNS query for SRV record returned $code";
		die "[AD] Cannot get PDC host name. DNS query for SRV record returned $code";
	}
	chomp $pdc_host;
	unless($pdc_host =~ s/^.* (.*).$/$1/) {
		ldap_log('ad_connection', "[AD] Cannot get PDC host name. Returned $pdc_host");
		print STDERR "[AD] Cannot get PDC host name. Returned $pdc_host";
		die "[AD] Cannot get PDC host name. Returned $pdc_host";
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
		print STDERR "[AD] can't connect to AD.";
		die "[AD] can't connect to AD.";
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

	open(LOGFILE, ">>./logs/" . $service . ".log") || die "Can't open log file './logs/$service.log'.";
	print LOGFILE (localtime(time) . ": " . $message . "\n");
	close(LOGFILE) || die "Can't close log file './logs/$service.log'.";

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
			push(@perun_entries, $entry) if (defined $entry and ($entry->get_value('cn') or $entry->get_value('ou')));
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
			push(@ad_entries,$entry) if ($entry->get_value('cn') or $entry->get_value('ou'));
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

#
# Compare new value with original entry value using Perls smart-match operator
#
# Takes:
# $ad_entry entry from AD to check on
# $perun_entry entry from Perun to compare with
# $param name of param to compare
#
# Return:
# 1 if param should be updated
# 0 otherwise
#
sub compare_entry($$$) {

	my $ad_entry = (@_)[0];
	my $perun_entry = (@_)[1];
	my $param = (@_)[2];

	# get value
	my @ad_entry_value = $ad_entry->get_value($param);
	my @perun_entry_value = $perun_entry->get_value($param);

	# sort for multi-valued
	my @sorted_ad_entry_value = sort(@ad_entry_value);
	my @sorted_perun_entry_value = sort(@perun_entry_value);

	# compare using smart-match (perl 5.10.1+)
	unless(@sorted_ad_entry_value ~~ @sorted_perun_entry_value) {
		# param values are not equals
		return 1;
	}

	# values are equals
	return 0;

}

#
# Set MS AD UAC value to "enabled" by setting 2nd bit of passed value to 0.
# It doesn't modify other UAC settings !!
#
# Takes:
# $uac UAC value to be set to "enabled" state
#
# Return:
# UAC value in "enabled" state (with 2nd bit = 0).
#
sub enable_uac($) {

	my $uac = shift;
	$uac = $uac & ~2;
	return $uac;

}

#
# Set MS AD UAC value to "disabled" by setting 2nd bit of passed value to 1.
# It doesn't modify other UAC settings !!
#
# Takes:
# $uac UAC value to be set to "disabled" state
#
# Return:
# UAC value in "disabled" state (with 2nd bit = 1).
#
sub disable_uac($) {

	my $uac = shift;
	$uac = $uac | (1<<1);
	return $uac;

}

#
# Return 1 if MS AD UAC value is "enabled", 0 if "disabled".
#
# Takes:
# $uac UAC value to check "enabled" state (check in 2nd bit is set)
#
# Return:
# 1 if enabled (true)
# 0 if disabled (false)
#
sub is_uac_enabled($) {

	my $uac = shift;
	if ($uac & (1<<1)) {
		return 0;
	} else {
		return 1;
	}

}

#
# Create clone of an existing ldap entry with specified attributes
#
# Takes:
# LDAP entry which will be cloned
# Attributes which will be cloned among the entries
#
# Return:
# Copy of the given LDAP entry with the specified attributes
#
sub clone_entry_with_specific_attributes($$) {
	my $entry = shift;
	my $attrs = shift;

	my $clone = Net::LDAP::Entry->new($entry->dn());

	foreach my $attr (@{$attrs}) {
		my @value = $entry->get_value($attr);
		$clone->add(
			$attr => \@value
		);
	}

	return $clone;
}

1;
