#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use Getopt::Long qw(:config no_ignore_case);
use Data::Dumper;

my $username;
my $password;
my $dbname;
my $pathToServiceFile;
my $serviceName;
my $tableName;

our $FIRSTNAME = 'FIRSTNAME';
our $LASTNAME = 'LASTNAME';
our $GOLD = 'GOLD';
our $ACC_GROUPS = 'ACC_GROUPS';
our $LOGIN = 'LOGIN';
our $TYPE = 'TYPE';

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
	}
}

if(!defined($password) || !defined($username) || !defined($tableName)) {
	print "Can't get config data from config file.\n";
	exit 14;
}

#Main Structure
my $dataByChip = {};

open FILE, $filename or die "Could not open $filename: $!";
while(my $line = <FILE>) {
	chomp( $line );
	my @parts = split /\t/, $line;
	$dataByChip->{$parts[0]}->{$FIRSTNAME} = $parts[1];
	$dataByChip->{$parts[0]}->{$LASTNAME} = $parts[2];
	$dataByChip->{$parts[0]}->{$LOGIN} = $parts[3];
	$dataByChip->{$parts[0]}->{$TYPE} = $parts[4];
	if($parts[5] && $parts[6]) {
		$dataByChip->{$parts[0]}->{$GOLD} = 3;
	} elsif ($parts[6]) {
		$dataByChip->{$parts[0]}->{$GOLD} = 4;
	} elsif ($parts[5]) {
		$dataByChip->{$parts[0]}->{$GOLD} = 2;
	} else {
		$dataByChip->{$parts[0]}->{$GOLD} = 1;
	}
	$dataByChip->{$parts[0]}->{$ACC_GROUPS} = $parts[7];
}
close FILE;

my $dbh = DBI->connect("dbi:Oracle:$dbname",$username, $password,{RaiseError=>1,AutoCommit=>0,LongReadLen=>65536, ora_charset => 'AL32UTF8'}) or die "Connect to database $dbname Error!\n";

###TEMP DELETE ALL (clear DB)
#my $deleteAllChips = $dbh->prepare(qq{DELETE from $tableName});
#$deleteAllChips->execute();
#commit $dbh;
#$dbh->disconnect();
#exit 0;
### TEMP


my $DEBUG=0;
#statistic and information variables
my $foundAndSkipped = 0;
my $foundAndUpdated = 0;
my $inserted = 0;
my $removed = 0;
my $deleted = 0;

#update and insert new or updated chips
my @allChipsArray = ();
foreach my $chipNumber (sort keys $dataByChip) {
	my $firstName = $dataByChip->{$chipNumber}->{$FIRSTNAME};
	my $lastName = $dataByChip->{$chipNumber}->{$LASTNAME};
	my $UIN = $dataByChip->{$chipNumber}->{$LOGIN};
	my $cardType = $dataByChip->{$chipNumber}->{$GOLD};
	my $accGroups = $dataByChip->{$chipNumber}->{$ACC_GROUPS};
	my $identityType = $dataByChip->{$chipNumber}->{$TYPE};
	push @allChipsArray, $chipNumber . ":" . $UIN;

	#Card Number with UIN is primary key there
	my $chipExists = $dbh->prepare(qq{select 1 from $tableName where CardNumber=? and UIN=?});
	$chipExists->execute($chipNumber, $UIN);
	if($chipExists->fetch) {
		if($DEBUG == 1) { print "FIND: $chipNumber\n"; }
		#we need to know if these two records are without changes, if yes, skip them
		my $recordAreEquals = $dbh->prepare(qq{SELECT 1 from $tableName where CardNumber=? and UIN=? and CardType=? and AccessGroups=? and FirstName=? and SecondName=? and IdentityType=?});
		$recordAreEquals->execute($chipNumber, $UIN, $cardType, $accGroups, $firstName, $lastName, $identityType);
		if(!$recordAreEquals->fetch) {
			my $updateChip = $dbh->prepare(qq{UPDATE $tableName SET PROCESSED=1, CardType=?, AccessGroups=?, FirstName=?, SecondName=?, IdentityType=? WHERE CardNumber=? AND UIN=?});
			$updateChip->execute($cardType, $accGroups, $firstName, $lastName, $identityType, $chipNumber, $UIN);
			if($DEBUG == 1) { print "UPDATING EXISTING RECORD: $chipNumber\n"; }
			$foundAndUpdated++;
		} else {
			if($DEBUG == 1) { print "SKIP RECORD: $chipNumber\n"; }
			$foundAndSkipped++;
		}
	} else {
		if($DEBUG == 1) { print "INSERT NEW RECORD: $chipNumber\n"; }
		$inserted++;
		#we will do insert
		my $insertChip = $dbh->prepare(qq{INSERT INTO $tableName (PROCESSED, UIN, CardNumber, IdentityType, CardType, AccessGroups, FirstName, SecondName) VALUES (1,?,?,?,?,?,?,?)});
		$insertChip->execute($UIN, $chipNumber, $identityType, $cardType, $accGroups, $firstName, $lastName);
	}
}

my @chipsToDeleteFromDB = ();
my $chipsToDeleteFromDBQuerry = $dbh->prepare(qq{SELECT CardNumber, UIN from $tableName where AccessGroups IS NULL and CardType=1 and PROCESSED=0});
$chipsToDeleteFromDBQuerry->execute();
while(my $chtd = $chipsToDeleteFromDBQuerry->fetch) {
	push @chipsToDeleteFromDB, $$chtd[0] . ":" . $$chtd[1];
}
my %tmpDelete = map {$_ => 1} @allChipsArray;
my @chipsToDelete = grep {not $tmpDelete{$_}} @chipsToDeleteFromDB;
foreach my $chipToDelete (@chipsToDelete) {
        if($DEBUG == 1) {  print "DELETE RECORD: $chipToDelete\n"; }
	$deleted++;
        my $deleteChip = $dbh->prepare(qq{DELETE from $tableName where CardNumber=? and UIN=?});
	my $deletedChipNumber = (split(/:/, $chipToDelete))[0];
	my $deletedChipUID = (split(/:/, $chipToDelete))[1];
        $deleteChip->execute($deletedChipNumber, $deletedChipUID);
}

my @chipsToRemoveFromDB = ();
my $chipsToRemoveFromDBQuerry = $dbh->prepare(qq{SELECT CardNumber, UIN from $tableName});
$chipsToRemoveFromDBQuerry->execute();
while(my $chtr = $chipsToRemoveFromDBQuerry->fetch) {
        push @chipsToRemoveFromDB, $$chtr[0] . ":" . $$chtr[1];
}
my %tmpRemove = map {$_ => 1} @allChipsArray;
my @chipsToRemove = grep {not $tmpRemove{$_}} @chipsToRemoveFromDB;

foreach my $chipToRemove (@chipsToRemove) {
        if($DEBUG == 1) { print "REMOVE RECORD: $chipToRemove\n"; }
	$removed++;
	my $removedChip = $dbh->prepare(qq{UPDATE $tableName SET PROCESSED=1, CardType=1, AccessGroups=NULL where CardNumber=? and UIN=?});
	my $removedChipNumber = (split(/:/, $chipToRemove))[0];
        my $removedChipUID = (split(/:/, $chipToRemove))[1];
	$removedChip->execute($removedChipNumber, $removedChipUID);
}

commit $dbh;
$dbh->disconnect();

#Info about operations
print "=======================================\n";
print "Newly inserted:   \t$inserted\n";
print "Found and skiped: \t$foundAndSkipped\n";
print "Found and updated:\t$foundAndUpdated\n";
print "Set to remove:    \t$removed\n";
print "Deleted:          \t$deleted\n";
print "=======================================\n";

exit 0;
