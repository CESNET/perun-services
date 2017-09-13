#!/usr/bin/perl
use strict;
use warnings;

sub getAllAccounts;
sub createAccount;
sub updateAccount;
sub createAccounts;
sub updateAccounts;
sub compareAndUpdateAttribute;
sub logMessage;

my $perunAccounts;  # $perunAccounts->{login}->{MAILBOX|givenName|sn|displayName|zimbraAccountStatus|zimbraCOSid}=value
my $zimbraAccounts;  # $zimbraAccounts->{login}->{MAILBOX|givenName|sn|displayName|zimbraAccountStatus|zimbraCOSid}=value

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
	$perunAccounts->{$parts[1]}->{'zimbraCOSid'} = (($parts[8] ne '') ? $parts[8] : undef);

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
					createAccount($perunAccounts->{$login});
				}

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
			compareAndUpdateAttribute($perunAccounts->{$login}, $zimbraAccounts->{$login}, "zimbraCOSid");
			compareAndUpdateAttribute($perunAccounts->{$login}, $zimbraAccounts->{$login}, "givenName");
			compareAndUpdateAttribute($perunAccounts->{$login}, $zimbraAccounts->{$login}, "sn");
			compareAndUpdateAttribute($perunAccounts->{$login}, $zimbraAccounts->{$login}, "displayName");
			compareAndUpdateAttribute($perunAccounts->{$login}, $zimbraAccounts->{$login}, "zimbraAccountStatus");

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
sub compareAndUpdateAttribute() {

	my $perunAccount = shift;
	my $zimbraAccount = shift;
	my $attrName = shift;

	if ($perunAccount->{$attrName} ne $zimbraAccount->{$attrName}) {

		# Zimbra can have uninitialized string value !! - breaks print
		my $zmval = $zimbraAccount->{$attrName};
		if (!defined $zmval) { $zmval = ''; }

		if ($dry_run) {
			print $perunAccount->{"MAILBOX"} . " $attrName would be updated '$zmval'=>'$perunAccount->{$attrName}'.\n";
			logMessage($perunAccount->{"MAILBOX"} . " $attrName would be updated '$zmval'=>'$perunAccount->{$attrName}'.");
		} else {
			my $ret = updateAccount($perunAccount->{"MAILBOX"}, $attrName, $perunAccount->{$attrName});
			if ($ret != 0) {
				print "ERROR: " . $perunAccount->{"MAILBOX"} . " update of $attrName failed.\n";
				logMessage("ERROR: " . $perunAccount->{"MAILBOX"} . " update of $attrName failed, ret.code: " . $ret);
			} else {
				print $perunAccount->{"MAILBOX"} . " $attrName updated '$zmval'=>'$perunAccount->{$attrName}'.\n";
				logMessage($perunAccount->{"MAILBOX"} . " $attrName updated '$zmval'=>'$perunAccount->{$attrName}'.\n");
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

	my $output = `sudo /opt/zimbra/bin/zmprov ca $account->{"MAILBOX"} '' zimbraCOSid $account->{"zimbraCOSid"} givenName $account->{"givenName"} sn $account->{"sn"} displayName $account->{"displayName"}`;
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
# 1. param: hash reference of account to be created
# 2. param: name of Zimbra attribute to update
# 3. param: value of Zimbra attribute to update
#
# Return: return code of zmprov command
#
sub updateAccount() {

	my $account = shift;
	my $attrName = shift;
	my $value = shift;

	my $output = `sudo /opt/zimbra/bin/zmprov ma $account->{"MAILBOX"} $attrName $value`;
	my $ret = $?; # get ret.code of backticks command
	$ret = ($ret >> 8); # shift 8 bits to get original return code

	# only for logging verbose output
	if ($ret != 0) {
		logMessage("ERROR: $account->{'MAILBOX'} attribute $attrName not updated, ret.code: $ret, output: $output.");
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
