#!/usr/bin/perl
use strict;
use warnings;

sub getAllAccounts;
sub updateAliases;
sub addAlias;
sub removeAlias;
sub setPrefFrom;
sub logMessage;

my $perunAccounts;  # $perunAccounts->{login}->{MAILBOX|zimbraPrefFromAddress|zimbraMailAlias}=value|value|{alias1 = 1, alias2 = 1}
my $zimbraAccounts;  # $zimbraAccounts->{login}->{MAILBOX|zimbraPrefFromAddress|zimbraMailAlias}=value|value|{alias1 = 1, alias2 = 1}

# IF SET TO 1, no changes are actually done to Zimbra mail server
my $dry_run = 0;

# read input files path
my $accountsFilePath = shift;
my $ignoredFilePath = shift;

#
# Read accounts sent from Perun
#
open FILE, "<" . $accountsFilePath;
my @lines = <FILE>;
close FILE;

foreach my $line ( @lines ) {

	my @parts = split /\t/, $line;
	chomp(@parts);

	$perunAccounts->{$parts[1]}->{'TYPE'} = $parts[2];   # original relation to prevent creation of wrong "active".
	$perunAccounts->{$parts[1]}->{'MAILBOX'} = $parts[3];
	$perunAccounts->{$parts[1]}->{'zimbraPrefFromAddress'} = (($parts[4] ne '') ? $parts[4] : undef);

	my $aliases = (($parts[5] ne '') ? $parts[5] : undef);
	if ($aliases) {
		my @existing_aliases = split /,/, $aliases;
		foreach my $alias (@existing_aliases) {
			$perunAccounts->{$parts[1]}->{'zimbraMailAlias'}->{$alias} = 1;
		}
	}

	# put prefered alias between aliases
	if ($perunAccounts->{$parts[1]}->{'zimbraPrefFromAddress'}) {
		$perunAccounts->{$parts[1]}->{'zimbraMailAlias'}->{$perunAccounts->{$parts[1]}->{'zimbraPrefFromAddress'}} = 1;
	} else {
		# prefered from is set to mailbox name - in such case is NOT alias
		$perunAccounts->{$parts[1]}->{'zimbraPrefFromAddress'} = $parts[3];
	}

}

#
# Read which accounts are supposed to be IGNORED by Perun
#
open FILE, "<" . $ignoredFilePath;
my @ignoredAccountsList = <FILE>;
close FILE;
chomp(@ignoredAccountsList);
my %ignoredAccounts = map { $_ => 1 } @ignoredAccountsList;

#
# Read existing accounts from Zimbra
#
$zimbraAccounts = getAllAccounts();

updateAliases();

exit 0;

#####################
#
# HELPING METHODS
#
#####################

#
# Read all accounts from Zimbra mail server
# Exit script with ret.code = 1 if contacting Zimbra fails.
#
sub getAllAccounts() {

	my $existingAccounts; # $existingAccounts->{login}->{MAILBOX|ALIAS|ALIASES}=value
	my $currentLogin;     # current step in output parsing

	# read versbose output of all accounts in zimbra
	my @output = `sudo -u zimbra /opt/zimbra/bin/zmprov -l gaa -v vsup.cz`;
	my $ret = $?; # get ret.code of backticks command
	$ret = ($ret >> 8); # shift 8 bits to get original return code

	if ($ret != 0) {
		print "Unable to read all accounts from Zimbra, err.code: $ret, output: @output";
		logMessage("Unable to read all accounts from Zimbra, err.code: $ret, output: @output");
		exit 1;
	}

	chomp(@output);

	foreach my $line (@output) {

		if ($line =~ m/^# name (.*\@vsup.cz)(.*)$/) {
			$currentLogin = ($line =~ m/^# name (.*)\@vsup.cz(.*)$/)[0];
			my $currentMailbox = ($line =~ m/^# name (.*\@vsup.cz)(.*)$/)[0];
			$existingAccounts->{$currentLogin}->{"MAILBOX"} = $currentMailbox;
		}

		if ($line =~ m/^zimbraMailAlias: (.*)$/) {
			my $currentAlias = ($line =~ m/^zimbraMailAlias: (.*)$/)[0];
			$existingAccounts->{$currentLogin}->{"zimbraMailAlias"}->{$currentAlias} = 1;
		}

		if ($line =~ m/^zimbraPrefFromAddress: (.*)$/) {
			my $currentPrefFrom = ($line =~ m/^zimbraPrefFromAddress: (.*)$/)[0];
			$existingAccounts->{$currentLogin}->{"zimbraPrefFromAddress"} = $currentPrefFrom;
		}

	}

	return $existingAccounts;

}

#
# Iterate through Zimbra and Perun accounts and update changed aliases and preferred from addresses
#
# Only accounts pushed from Perun are modified !!
#
sub updateAliases() {

	# 1. ADD all new aliases
	foreach my $login (sort keys %$perunAccounts) {

		# skip ignored
		if (exists $ignoredAccounts{$login}) {
			print $perunAccounts->{$login}->{"MAILBOX"} . " ignored.\n";
			logMessage("WARN: " . $zimbraAccounts->{$login}->{"MAILBOX"} . " not updated. Belongs to ignored.");
			next;
		}

		# skip not yet existing
		unless (exists $zimbraAccounts->{$login}) {
			print $perunAccounts->{$login}->{"MAILBOX"} . " ignored - not yet created in Zimbra.\n";
			logMessage("WARN: " . $zimbraAccounts->{$login}->{"MAILBOX"} . " not updated. Not yet created in Zimbra.");
			next;

		} else {

			# check and update existing
			my $perunAliases = $perunAccounts->{$login}->{"zimbraMailAlias"};
			my $zimbraAliases = $zimbraAccounts->{$login}->{"zimbraMailAlias"};
			my @to_be_added;
			foreach my $perunAlias (sort keys %{$perunAliases}) {
				unless (exists $zimbraAliases->{$perunAlias}) {
					push (@to_be_added, $perunAlias);
				}
			}

			foreach my $perunAlias (@to_be_added) {

				if ($dry_run) {
					print $perunAccounts->{$login}->{"MAILBOX"} . " alias would be added '$perunAlias'.\n";
					logMessage($perunAccounts->{$login}->{"MAILBOX"} . " alias would be added '$perunAlias'.");
				} else {
					addAlias($perunAccounts->{$login}->{"MAILBOX"}, $perunAlias);
				}

			}

		}

	}

	# 2. Set all pref addresses

	foreach my $login (sort keys %$perunAccounts) {

		# skip ignored
		if (exists $ignoredAccounts{$login}) {
			print $perunAccounts->{$login}->{"MAILBOX"} . " ignored.\n";
			logMessage("WARN: " . $zimbraAccounts->{$login}->{"MAILBOX"} . " not updated. Belongs to ignored.");
			next;
		}

		# skip not yet existing
		unless (exists $zimbraAccounts->{$login}) {

			print $perunAccounts->{$login}->{"MAILBOX"} . " ignored - not yet created in Zimbra.\n";
			logMessage("WARN: " . $zimbraAccounts->{$login}->{"MAILBOX"} . " not updated. Not yet created in Zimbra.");
			next;

		} else {

			# check and update existing

			my $perunPrefFromAddress = $perunAccounts->{$login}->{"zimbraPrefFromAddress"};
			my $zimbraPrefFromAddress = $zimbraAccounts->{$login}->{"zimbraPrefFromAddress"} || '';

			unless ($perunPrefFromAddress eq $zimbraPrefFromAddress) {

				if ($dry_run) {
					print $perunAccounts->{$login}->{"MAILBOX"} . " zimbraPrefFromAddress would be updated '$perunPrefFromAddress'.\n";
					logMessage($perunAccounts->{$login}->{"MAILBOX"} . " zimbraPrefFromAddress would be updated '$perunPrefFromAddress'.");
				} else {
					setPrefFrom($perunAccounts->{$login}->{"MAILBOX"}, $perunPrefFromAddress);
				}

			}

		}

	}

	# 3. Remove all deleted aliases

	foreach my $login (sort keys %$perunAccounts) {

		# skip ignored
		if (exists $ignoredAccounts{$login}) {
			print $perunAccounts->{$login}->{"MAILBOX"} . " ignored.\n";
			logMessage("WARN: " . $zimbraAccounts->{$login}->{"MAILBOX"} . " not updated. Belongs to ignored.");
			next;
		}

		# skip not yet existing
		unless (exists $zimbraAccounts->{$login}) {
			print $perunAccounts->{$login}->{"MAILBOX"} . " ignored - not yet created in Zimbra.\n";
			logMessage("WARN: " . $zimbraAccounts->{$login}->{"MAILBOX"} . " not updated. Not yet created in Zimbra.");
			next;

		} else {

			# check and update existing
			my $perunAliases = $perunAccounts->{$login}->{"zimbraMailAlias"};
			my $zimbraAliases = $zimbraAccounts->{$login}->{"zimbraMailAlias"};
			my @to_be_removed;
			foreach my $zimbraAlias (sort keys %{$zimbraAliases}) {
				unless (exists $perunAliases->{$zimbraAlias}) {
					push (@to_be_removed, $zimbraAlias);
				}
			}

			foreach my $zimbraAlias (@to_be_removed) {

				if ($dry_run) {
					print $perunAccounts->{$login}->{"MAILBOX"} . " alias would be removed '$zimbraAlias'.\n";
					logMessage($perunAccounts->{$login}->{"MAILBOX"} . " alias would be removed '$zimbraAlias'.");
				} else {
					removeAlias($perunAccounts->{$login}->{"MAILBOX"}, $zimbraAlias);
				}

			}

		}

	}

}

#
# Set one of aliases as PreferredFromAddress attribute in Zimbra
#
# 1. param: mailbox name
# 2. param: preferredFrom address
#
sub setPrefFrom() {

	my $account = shift;
	my $value = shift;

	my $output = `sudo -u zimbra /opt/zimbra/bin/zmprov ma '$account' zimbraPrefFromAddress '$value'`;
	my $ret = $?; # get ret.code of backticks command
	$ret = ($ret >> 8); # shift 8 bits to get original return code

	if ($ret != 0) {
		print "ERROR: $account preferred from address not set, ret.code: $ret, output: $output.\n";
		logMessage("ERROR: $account preferred from address not set, ret.code: $ret, output: $output.\n");
	} else {
		print "$account set preferred from address $value.\n";
		logMessage("$account set preferred from address $value, ret.code: $ret, output: $output.");
	}

}

#
# Add alias to Zimbra account
#
# 1. param: name of Zimbra account to update (mail)
# 2. param: value of alias to be added
#
# Return: return code of zmprov command
#
sub addAlias() {

	my $account = shift;
	my $alias = shift;

	my $output = `sudo -u zimbra /opt/zimbra/bin/zmprov aaa '$account' '$alias'`;
	my $ret = $?; # get ret.code of backticks command
	$ret = ($ret >> 8); # shift 8 bits to get original return code

	# only for logging verbose output
	if ($ret != 0) {
		print "ERROR: $account alias $alias not added.\n";
		logMessage("ERROR: $account alias $alias not added, ret.code: $ret, output: $output.");
	} else {
		print "$account alias $alias added.\n";
		logMessage("$account alias $alias added, ret.code: $ret, output: $output.");
	}

	return $ret;

}

#
# Remove alias from Zimbra account
#
# 1. param: name of Zimbra account to update (mail)
# 2. param: value of alias to be removed
#
# Return: return code of zmprov command
#
sub removeAlias() {

	my $account = shift;
	my $alias = shift;

	my $output = `sudo -u zimbra /opt/zimbra/bin/zmprov raa '$account' '$alias'`;
	my $ret = $?; # get ret.code of backticks command
	$ret = ($ret >> 8); # shift 8 bits to get original return code

	# only for logging verbose output
	if ($ret != 0) {
		print "ERROR: $account alias $alias not removed.\n";
		logMessage("ERROR: $account alias $alias not removed, ret.code: $ret, output: $output.");
	} else {
		print "$account alias $alias removed.\n";
		logMessage("$account alias $alias removed, ret.code: $ret, output: $output.");
	}

	return $ret;

}

#
# Log message to local file /home/perun/vsup_zimbra_aliases.log
#
# 1. param Message to log
#
sub logMessage() {
	my $message = shift;
	open(LOGFILE, ">>/home/perun/vsup_zimbra_aliases.log");
	print LOGFILE (localtime(time) . ": " . $message . "\n");
	close(LOGFILE);
}
