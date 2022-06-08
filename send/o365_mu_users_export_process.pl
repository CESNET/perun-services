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
	} elsif($line =~ /^database: .*/) {
		$database = ($line =~ m/^database: (.*)$/)[0];
	}
}

if(!defined($password) || !defined($username) || !defined($tableName) || !defined($database)) {
	print "Can't get config data from config file.\n";
	exit 14;
}

#Main Structure
my $validLogins = {};

open FILE, $filename or die "Could not open $filename: $!";
while(my $line = <FILE>) {
	chomp( $line );
	$validLogins->{$line} = $line;
}
close FILE;

my $dbh = DBI->connect("dbi:Oracle:$database",$username, $password,{RaiseError=>1,AutoCommit=>0,LongReadLen=>65536, ora_charset => 'AL32UTF8'}) or die "Connect to database $database Error!\n";

#statistic and information variables
my $skipped = 0;
my $inserted = 0;
my $deleted = 0;

#return all logins from the table
my $loginsInTable = {};
my $allLoginsFromTable = $dbh->prepare(qq{select distinct uco from $tableName});
$allLoginsFromTable->execute();
while(my $alft = $allLoginsFromTable->fetch) {
        $loginsInTable->{$$alft[0]} = $$alft[0];
}

#insert new logins
foreach my $uco (sort keys %$validLogins) {
	if($loginsInTable->{$uco}) {
		$skipped++;
	} else {
		my $insertLogin = $dbh->prepare(qq{INSERT INTO $tableName (uco) VALUES (?)});
		$insertLogin->execute($uco);
		$inserted++;	
	}
}

#remove old logins
foreach my $uco (sort keys %$loginsInTable) {
	unless($validLogins->{$uco}) {
		my $deleteLogin = $dbh->prepare(qq{DELETE from $tableName where uco=?});
		$deleteLogin->execute($uco);
		$deleted++;
	}
}

commit $dbh;
$dbh->disconnect();

#Info about operations
print "================================\n";
print "Inserted:\t$inserted\n";
print "Skipped: \t$skipped\n";
print "Deleted: \t$deleted\n";
print "================================\n";

exit 0;
