#!/usr/bin/perl
use strict;
use warnings;

sub getAllAccounts;
sub createAccount;
sub updateAccount;
sub createAccounts;
sub updateAccounts;
sub compareAndUpdateAttribute($$$);
sub addAlias;
sub removeAlias;
sub setPrefFrom;
sub resolveAliasChange;
sub logMessage;

my $perunAccounts;  # $perunAccounts->{login}->{MAILBOX|givenName|sn|displayName|zimbraAccountStatus|zimbraCOSId|zimbraPrefFromAddress|zimbraMailAlias}=value
my $zimbraAccounts;  # $zimbraAccounts->{login}->{MAILBOX|givenName|sn|displayName|zimbraAccountStatus|zimbraCOSId|zimbraPrefFromAddress|zimbraMailAlias}=value

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
	$perunAccounts->{$parts[1]}->{'givenName'} = (($parts[4] ne '') ? $parts[4] : undef);
	$perunAccounts->{$parts[1]}->{'sn'} = (($parts[5] ne '') ? $parts[5] : undef);
	$perunAccounts->{$parts[1]}->{'displayName'} = (($parts[6] ne '') ? $parts[6] : undef);
	$perunAccounts->{$parts[1]}->{'zimbraAccountStatus'} = (($parts[7] ne '') ? $parts[7] : undef);
	$perunAccounts->{$parts[1]}->{'zimbraCOSId'} = (($parts[8] ne '') ? $parts[8] : undef);
	$perunAccounts->{$parts[1]}->{'zimbraPrefFromAddress'} = (($parts[9] ne '') ? $parts[9] : undef);

	my $aliases = (($parts[10] ne '') ? $parts[10] : undef);
	if ($aliases) {
		my @existing_aliases = split /,/, $aliases;
		foreach my $alias (@existing_aliases) {
			$perunAccounts->{$parts[1]}->{'zimbraMailAlias'}->{$alias} = 1;
		}
	} else {
		# no aliases -> set to empty hash ref, so we can safely "sort keys" on it later
		$perunAccounts->{$parts[1]}->{'zimbraMailAlias'} = {};
	}

	# put preferred alias between aliases
	if ($perunAccounts->{$parts[1]}->{'zimbraPrefFromAddress'}) {
		$perunAccounts->{$parts[1]}->{'zimbraMailAlias'}->{$perunAccounts->{$parts[1]}->{'zimbraPrefFromAddress'}} = 1;
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

createAccounts();
updateAccounts();

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

	my $existingAccounts; # $existingAccounts->{login}->{MAILBOX|COS|STATUS|NAME}=value
	my $currentLogin;     # current step in output parsing

	# read versbose output of all accounts in zimbra
	my @output = `sudo /opt/zimbra/bin/zmprov -l gaa -v vsup.cz`;
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
			# expect COS is default for each entry if not present
			$existingAccounts->{$currentLogin}->{"zimbraCOSId"} = "e00428a1-0c00-11d9-836a-000d93afea2a";
		}

		if ($line =~ m/^zimbraAccountStatus: (.*)$/) {
			my $currentStatus = ($line =~ m/^zimbraAccountStatus: (.*)$/)[0];
			$existingAccounts->{$currentLogin}->{"zimbraAccountStatus"}=$currentStatus;
		}

		# replace default COS with actuall value if present
		if ($line =~ m/^zimbraCOSId: (.*)$/) {
			my $currentCos = ($line =~ m/^zimbraCOSId: (.*)$/)[0];
			$existingAccounts->{$currentLogin}->{"zimbraCOSId"} = $currentCos;
		}

		if ($line =~ m/^displayName: (.*)$/) {
			my $currentName = ($line =~ m/^displayName: (.*)$/)[0];
			$existingAccounts->{$currentLogin}->{"displayName"} = $currentName;
		}

		if ($line =~ m/^givenName: (.*)$/) {
			my $currentName = ($line =~ m/^givenName: (.*)$/)[0];
			$existingAccounts->{$currentLogin}->{"givenName"} = $currentName;
		}

		if ($line =~ m/^sn: (.*)$/) {
			my $currentName = ($line =~ m/^sn: (.*)$/)[0];
			$existingAccounts->{$currentLogin}->{"sn"} = $currentName;
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
# Create new accounts in Zimbra.
# only 'active' and not ignored accounts are created.
#
sub createAccounts() {

	print "Create accounts\n--------------\n";

	foreach my $login (sort keys %$perunAccounts) {
		unless (exists $zimbraAccounts->{$login}) {

			# try to create new account

			if (exists $ignoredAccounts{$login}) {
				# skip IGNORED accounts
				print $perunAccounts->{$login}->{"MAILBOX"} . " ignored.\n";
				logMessage("WARN: " . $perunAccounts->{$login}->{"MAILBOX"} . " not created. Belongs to ignored.");
				next;
			}

			if (($perunAccounts->{$login}->{"zimbraAccountStatus"} eq 'active') and ($perunAccounts->{$login}->{"TYPE"} ne 'EXPIRED')) {

				# create new account for active STU/ZAM
				if ($dry_run) {
					print $perunAccounts->{$login}->{"MAILBOX"} . " would be created.\n";
					logMessage($perunAccounts->{$login}->{"MAILBOX"} . " would be created.");
				} else {
					# create account
					createAccount($perunAccounts->{$login});
				}

				# has dry-run inside
				resolveAliasChange($perunAccounts->{$login}, undef);

			} else {

				# not-active or EXPIRED accounts are not created in Zimbra again !
				print $perunAccounts->{$login}->{"MAILBOX"} . " skipped.\n";
				logMessage("WARN: " . $perunAccounts->{$login}->{"MAILBOX"} . " not created - is not in active state and was probably manually deleted from Zimbra.");

			}

		}
	}

}

#
# Iterate through Zimbra and Perun accounts and update changed attributes
# also 'close' accounts left in Zimbra which are missing in Perun.
#
sub updateAccounts() {

	print "Update accounts\n--------------\n";

	foreach my $login (sort keys %$zimbraAccounts) {

		if (exists $ignoredAccounts{$login}) {
			print $zimbraAccounts->{$login}->{"MAILBOX"} . " ignored.\n";
			logMessage("WARN: " . $zimbraAccounts->{$login}->{"MAILBOX"} . " not updated. Belongs to ignored.");
			next;
		}

		if (exists $perunAccounts->{$login}) {

			# compare and update each attribute
			compareAndUpdateAttribute($perunAccounts->{$login}, $zimbraAccounts->{$login}, "zimbraCOSId");
			compareAndUpdateAttribute($perunAccounts->{$login}, $zimbraAccounts->{$login}, "givenName");
			compareAndUpdateAttribute($perunAccounts->{$login}, $zimbraAccounts->{$login}, "sn");
			compareAndUpdateAttribute($perunAccounts->{$login}, $zimbraAccounts->{$login}, "displayName");
			compareAndUpdateAttribute($perunAccounts->{$login}, $zimbraAccounts->{$login}, "zimbraAccountStatus");

			resolveAliasChange($perunAccounts->{$login}, $zimbraAccounts->{$login});

		} else {

			# is missing from perun but present in zimbra => 'closed', in future delete !!

			if ($zimbraAccounts->{$login}->{"zimbraAccountStatus"} ne 'closed') {

				if ($dry_run) {
					print $zimbraAccounts->{$login}->{"MAILBOX"}." would be closed.\n";
					logMessage($zimbraAccounts->{$login}->{"MAILBOX"}." would be closed.");
				} else {
					my $ret = updateAccount($zimbraAccounts->{$login}->{"MAILBOX"}, "zimbraAccountStatus", 'closed');
					if ($ret != 0) {
						print "ERROR: " . $zimbraAccounts->{$login}->{"MAILBOX"} . " not closed.\n";
						logMessage("ERROR: ".$zimbraAccounts->{$login}->{"MAILBOX"}." not closed, ret.code: ".$ret);
					} else {
						print $zimbraAccounts->{$login}->{"MAILBOX"}." closed.\n";
						logMessage($zimbraAccounts->{$login}->{"MAILBOX"}." closed.");
					}
				}
			} else {
				logMessage($zimbraAccounts->{$login}->{"MAILBOX"}." already is closed - skipped.");
			}

			resolveAliasChange(undef, $zimbraAccounts->{$login});

		}
	}

}

#
# Compare Zimbra account attribute between Zimbra and Perun version
# and perform update if necessary
#
# 1. param: hash reference of perun account
# 2. param: hash reference of zimbra account
# 3. param: name of attribute
#
sub compareAndUpdateAttribute($$$) {

	my $perunAccount = shift;
	my $zimbraAccount = shift;
	my $attrName = shift;

	# Make sure comparison and print work
	my $perunAttr = ($perunAccount->{$attrName}) ? $perunAccount->{$attrName} : '';
	my $zimbraAttr = ($zimbraAccount->{$attrName}) ? $zimbraAccount->{$attrName} : '';

	if ($perunAttr ne $zimbraAttr) {

		if ($dry_run) {
			print $perunAccount->{"MAILBOX"} . " $attrName would be updated '$zimbraAttr'=>'$perunAttr'.\n";
			logMessage($perunAccount->{"MAILBOX"} . " $attrName would be updated '$zimbraAttr'=>'$perunAttr'.");
		} else {
			# user original value in update call
			my $ret = updateAccount($perunAccount->{"MAILBOX"}, $attrName, $perunAccount->{$attrName});
			if ($ret != 0) {
				print "ERROR: " . $perunAccount->{"MAILBOX"} . " update of $attrName failed.\n";
				logMessage("ERROR: " . $perunAccount->{"MAILBOX"} . " update of $attrName failed, ret.code: " . $ret);
			} else {
				print $perunAccount->{"MAILBOX"} . " $attrName updated '$zimbraAttr'=>'$perunAttr'.\n";
				logMessage($perunAccount->{"MAILBOX"} . " $attrName updated '$zimbraAttr'=>'$perunAttr'.\n");
			}
		}
	}

}

#
# Compare Zimbra account aliases and prefFrom attributes between Zimbra and Perun version
# and perform update if necessary
#
# 1. param: hash reference of perun account
# 2. param: hash reference of zimbra account
#
sub resolveAliasChange() {

	my $perunAccount = shift;
	my $zimbraAccount = shift;

	if (!$perunAccount && $zimbraAccount) {

		# CLOSING/DELETING ZIMBRA ACCOUNT -> remove preferred from and aliases

		# 1. unset preferred from address
		my $zimbraAttr = $zimbraAccount->{'zimbraPrefFromAddress'};
		my $zimbraAliases = ($zimbraAccount->{'zimbraMailAlias'}) ? $zimbraAccount->{'zimbraMailAlias'} : {};

		if ($zimbraAttr) {
			# only if previously preferred mail was set
			if ($dry_run) {
				print $zimbraAccount->{"MAILBOX"} . " 'zimbraPrefFromAddress' would be updated '$zimbraAttr'=>''.\n";
				logMessage($zimbraAccount->{"MAILBOX"} . " 'zimbraPrefFromAddress' would be updated '$zimbraAttr'=>''.");
			} else {
				# set preferred from to '' (aka empty it)
				my $ret = updateAccount($zimbraAccount->{"MAILBOX"}, 'zimbraPrefFromAddress', '');
				if ($ret != 0) {
					print "ERROR: " . $zimbraAccount->{"MAILBOX"} . " update of 'zimbraPrefFromAddress' failed.\n";
					logMessage("ERROR: " . $zimbraAccount->{"MAILBOX"} . " update of 'zimbraPrefFromAddress' failed, ret.code: " . $ret);
				} else {
					print $zimbraAccount->{"MAILBOX"} . " 'zimbraPrefFromAddress' updated '$zimbraAttr'=>''.\n";
					logMessage($zimbraAccount->{"MAILBOX"} . " 'zimbraPrefFromAddress' updated '$zimbraAttr'=>''.\n");
				}
			}
		}

		# 2. remove non-existing aliases
		foreach my $zimbraAlias (sort keys %{$zimbraAliases}) {
			if ($dry_run) {
				print $zimbraAccount->{"MAILBOX"} . " alias would be removed '$zimbraAlias'.\n";
				logMessage($zimbraAccount->{"MAILBOX"} . " alias would be removed '$zimbraAlias'.");
			} else {
				removeAlias($zimbraAccount->{"MAILBOX"}, $zimbraAlias);
			}
		}

	} elsif ($perunAccount && $zimbraAccount) {

		# UPDATE ZIMBRA ACCOUNT -> add and remove aliases, set preferred

		my $perunAliases = $perunAccount->{"zimbraMailAlias"}; # set to empty hash ref from perun if empty, so it's safe
		my $zimbraAliases = ($zimbraAccount->{"zimbraMailAlias"}) ? $zimbraAccount->{"zimbraMailAlias"} : {};

		# 1. add missing aliases
		my @to_be_added;
		foreach my $perunAlias (sort keys %{$perunAliases}) {
			unless (exists $zimbraAliases->{$perunAlias}) {
				push (@to_be_added, $perunAlias);
			}
		}

		foreach my $perunAlias (@to_be_added) {
			if ($dry_run) {
				print $perunAccount->{"MAILBOX"} . " alias would be added '$perunAlias'.\n";
				logMessage($perunAccount->{"MAILBOX"} . " alias would be added '$perunAlias'.");
			} else {
				addAlias($perunAccount->{"MAILBOX"}, $perunAlias);
			}
		}

		# 2. set preferred from address (usually one of aliases)
		compareAndUpdateAttribute($perunAccount, $zimbraAccount, "zimbraPrefFromAddress");

		# 3. remove non-existing aliases
		my @to_be_removed;
		foreach my $zimbraAlias (sort keys %{$zimbraAliases}) {
			unless (exists $perunAliases->{$zimbraAlias}) {
				push (@to_be_removed, $zimbraAlias);
			}
		}

		foreach my $zimbraAlias (@to_be_removed) {
			if ($dry_run) {
				print $perunAccount->{"MAILBOX"} . " alias would be removed '$zimbraAlias'.\n";
				logMessage($perunAccount->{"MAILBOX"} . " alias would be removed '$zimbraAlias'.");
			} else {
				removeAlias($perunAccount->{"MAILBOX"}, $zimbraAlias);
			}
		}

	} elsif ($perunAccount && !$zimbraAccount) {

		# CREATE/ENABLE ZIMBRA ACCOUNT

		my $perunAliases = $perunAccount->{"zimbraMailAlias"};
		my $perunAttr = $perunAccount->{'zimbraPrefFromAddress'};

		# 1. add missing aliases
		foreach my $perunAlias (sort keys %{$perunAliases}) {
			if ($dry_run) {
				print $perunAccount->{"MAILBOX"} . " alias would be added '$perunAlias'.\n";
				logMessage($perunAccount->{"MAILBOX"} . " alias would be added '$perunAlias'.");
			} else {
				addAlias($perunAccount->{"MAILBOX"}, $perunAlias);
			}
		}

		# 2. set preferred from address (usually one of aliases) and only if exists
		if ($perunAttr) {
			if ($dry_run) {
				print $perunAccount->{"MAILBOX"} . " 'zimbraPrefFromAddress' would be updated '$perunAttr'=>''.\n";
				logMessage($perunAccount->{"MAILBOX"} . " 'zimbraPrefFromAddress' would be updated '$perunAttr'=>''.");
			} else {
				# user original value in update call
				my $ret = updateAccount($perunAccount->{"MAILBOX"}, 'zimbraPrefFromAddress', $perunAttr);
				if ($ret != 0) {
					print "ERROR: " . $perunAccount->{"MAILBOX"} . " update of 'zimbraPrefFromAddress' failed.\n";
					logMessage("ERROR: " . $perunAccount->{"MAILBOX"} . " update of 'zimbraPrefFromAddress' failed, ret.code: " . $ret);
				} else {
					print $perunAccount->{"MAILBOX"} . " 'zimbraPrefFromAddress' updated '$perunAttr'=>''.\n";
					logMessage($perunAccount->{"MAILBOX"} . " 'zimbraPrefFromAddress' updated '$perunAttr'=>''.\n");
				}
			}

		}
	}

}

#
# Create single account in Zimbra and print/log the output
#
# 1. param: hash reference of account to be created
#
sub createAccount() {

	my $account = shift;

	my $output = `sudo /opt/zimbra/bin/zmprov ca '$account->{"MAILBOX"}' '' zimbraCOSid '$account->{"zimbraCOSId"}' givenName '$account->{"givenName"}' sn '$account->{"sn"}' displayName '$account->{"displayName"}'`;
	my $ret = $?; # get ret.code of backticks command
	$ret = ($ret >> 8); # shift 8 bits to get original return code

	if ($ret != 0) {
		print "ERROR: $account->{'MAILBOX'} not created, ret.code: $ret, output: $output.\n";
		logMessage("ERROR: $account->{'MAILBOX'} not created, ret.code: $ret, output: $output.");
	} else {
		print "$account->{'MAILBOX'} created.\n";
		logMessage("$account->{'MAILBOX'} created, ret.code: $ret, output: $output.");
	}

}

#
# Update account single attribute in Zimbra
#
# 1. param: name of Zimbra account to update (mail)
# 2. param: name of Zimbra attribute to update
# 3. param: value of Zimbra attribute to update
#
# Return: return code of zmprov command
#
sub updateAccount() {

	my $account = shift;
	my $attrName = shift;
	my $value = shift;

	my $output = `sudo /opt/zimbra/bin/zmprov ma '$account' $attrName '$value'`;
	my $ret = $?; # get ret.code of backticks command
	$ret = ($ret >> 8); # shift 8 bits to get original return code

	# only for logging verbose output
	if ($ret != 0) {
		logMessage("ERROR: $account attribute $attrName not updated, ret.code: $ret, output: $output.");
	}

	return $ret;

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

	my $output = `sudo /opt/zimbra/bin/zmprov aaa '$account' '$alias'`;
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

	my $output = `sudo /opt/zimbra/bin/zmprov raa '$account' '$alias'`;
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
# Log message to local file /home/perun/vsup_zimbra.log
#
# 1. param Message to log
#
sub logMessage() {
	my $message = shift;
	open(LOGFILE, ">>/home/perun/vsup_zimbra.log");
	print LOGFILE (localtime(time) . ": " . $message . "\n");
	close(LOGFILE);
}
