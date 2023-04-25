#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use Getopt::Long qw(:config no_ignore_case);
use Data::Dumper;

my $username;
my $password;
my $dbname;
my $database;
my $pathToServiceFile;
my $serviceName;
my $tableName;
my $MFATableName;

GetOptions ("dbname|d=s" => \$dbname, "pathToServiceFile|p=s" => \$pathToServiceFile, "serviceName|s=s" => \$serviceName);

if(!defined $dbname) {
	print "Missing DBNAME to process service.\n";
	exit 10;
}

if(!defined $pathToServiceFile) {
  print "Missing path to file with generated data to process service.\n";
  exit 11;
}

if(!defined $serviceName) {
  print "Missing info about service name to process service.\n";
  exit 12;
}

my $filenameMFA = "$pathToServiceFile/$serviceName"."_mfa";
my $filename = "$pathToServiceFile/$serviceName";
if(! -f $filename) {
	print "Missing service file with data.\n";
	exit 13;
}

my $configPath = "/etc/perun/services/$serviceName/$dbname";
open FILE, $configPath or die "Could not open config file $configPath: $!";
while(my $line = <FILE>) {
	if($line =~ /^username: .*/) {
		$username = ($line =~ m/^username: (.*)$/)[0];
	} elsif($line =~ /^password: .*/) {
		$password = ($line =~ m/^password: (.*)$/)[0];
	} elsif($line =~ /^tablename: .*/) {
		$tableName = ($line =~ m/^tablename: (.*)$/)[0];
	} elsif($line =~ /^mfatablename: .*/) {
		$MFATableName = ($line =~ m/^mfatablename: (.*)$/)[0];
	} elsif($line =~ /^database: .*/) {
		$database = ($line =~ m/^database: (.*)$/)[0];
	}
}

if(!defined($password) || !defined($username) || !defined($tableName) || !defined($database)) {
	print "Can't get config data from config file.\n";
	exit 14;
}

#Main Structure
my $validLoginsMFA = {};
my $validLoginsO365 = {};

if (defined($MFATableName)) {
	if (! -f $filenameMFA) {
		print "MFA table is set in the config file, but service file with MFA data is missing. \n";
		exit 15;
	}
	open FILE, $filenameMFA or die "Could not open $filenameMFA: $!";
	while(my $line = <FILE>) {
		chomp( $line );
		my @parts = split /\t/, $line;
		my $uco = $parts[0];
		my $mfaStatus = $parts[1];
		$validLoginsMFA->{$uco} = $mfaStatus;
	}
	close FILE;
}

open FILE, $filename or die "Could not open $filename: $!";
while(my $line = <FILE>) {
	chomp( $line );
	$validLoginsO365->{$line} = $line;
}
close FILE;

my $dbh = DBI->connect("dbi:Oracle:$database",$username, $password,{RaiseError=>1,AutoCommit=>0,LongReadLen=>65536, ora_charset => 'AL32UTF8'}) or die "Connect to database $database Error!\n";
# prepare queries
my $insertLogin = $dbh->prepare(qq{INSERT INTO $tableName (uco) VALUES (?)});
my $deleteLogin = $dbh->prepare(qq{DELETE from $tableName where uco=?});
my $updateLoginMFA = $dbh->prepare(qq{UPDATE $MFATableName SET mfa=? WHERE uco=?});
my $deleteLoginMFA = $dbh->prepare(qq{DELETE from $MFATableName where uco=?});
my $insertLoginMFA = $dbh->prepare(qq{INSERT INTO $MFATableName (uco, mfa) VALUES (?, ?)});
my $allLoginsFromTable = $dbh->prepare(qq{select distinct uco from $tableName});
my $allLoginsFromMFATable = $dbh->prepare(qq{select uco, mfa from $MFATableName});

#statistic and information variables
my $skipped = 0;
my $inserted = 0;
my $deleted = 0;
my $skippedMFA = 0;
my $insertedMFA = 0;
my $deletedMFA = 0;
my $updatedMFA = 0;

#return all logins from the table
my $loginsInTable = {};
$allLoginsFromTable->execute();
while(my $alft = $allLoginsFromTable->fetch) {
        $loginsInTable->{$$alft[0]} = $$alft[0];
}

#insert new logins
foreach my $uco (sort keys %$validLoginsO365) {
	if($loginsInTable->{$uco}) {
		$skipped++;
	} else {
		$insertLogin->execute($uco);
		$inserted++;	
	}
}

#remove old logins
foreach my $uco (sort keys %$loginsInTable) {
	unless($validLoginsO365->{$uco}) {
		$deleteLogin->execute($uco);
		$deleted++;
	}
}

# MFA TABLE
# only process MFA information if the name of the MFA table is configured
#return all logins from the MFA table (in case MFA table has not yet been filled => logins in this table would not match the other table)
my $loginsInMFATable = {};
if (defined $MFATableName) {
	$allLoginsFromMFATable->execute();
	while (my $alft = $allLoginsFromMFATable->fetch) {
		$loginsInMFATable->{$$alft[0]} = $$alft[1];
	}

	foreach my $uco (sort keys %$validLoginsMFA) {
		if ($loginsInMFATable->{$uco}) {
			if ($loginsInMFATable->{$uco} ne $validLoginsMFA->{$uco} && $validLoginsMFA->{$uco} ne "none") {
				#update different mfa settings
				$updateLoginMFA->execute($validLoginsMFA->{$uco}, $uco);
				$updatedMFA++;
			}
			elsif ($validLoginsMFA->{$uco} eq "none") {
				#delete users that no longer have mfa settings
				$deleteLoginMFA->execute($uco);
				$deletedMFA++;
			}
			else {
				$skippedMFA++;
			}
		}
		elsif ($validLoginsMFA->{$uco} ne "none") {
			#insert new mfa settings
			$insertLoginMFA->execute($uco, $validLoginsMFA->{$uco});
			$insertedMFA++;
		}
		else {
			$skippedMFA++;
		}
	}


	#remove old logins MFA
	foreach my $uco (sort keys %$loginsInMFATable) {
		unless ($validLoginsMFA->{$uco}) {
			$deleteLoginMFA->execute($uco);
			$deletedMFA++;
		}
	}
}

commit $dbh;
$dbh->disconnect();

#Info about operations
print "================================\n";
print "Table $tableName:\n";
print "Inserted:\t$inserted\n";
print "Skipped: \t$skipped\n";
print "Deleted: \t$deleted\n";
if (defined $MFATableName) {
	print "\n";
	print "Table $MFATableName:\n";
	print "Inserted:\t$insertedMFA\n";
	print "Skipped: \t$skippedMFA\n";
	print "Deleted: \t$deletedMFA\n";
	print "Updated: \t$updatedMFA\n";
}
print "================================\n";

exit 0;
