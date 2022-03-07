#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use Getopt::Long qw(:config no_ignore_case);
use Data::Dumper;

my $username;
my $password;
my $hostname;
my $port;
my $groupsTableName;
my $usersTableName;
my $database;

#mandatory variables
my $dbname;
my $pathToServiceFile;
my $serviceName;

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
	} elsif($line =~ /^database: .*/) {
		$database = ($line =~ m/^database: (.*)$/)[0];
	} elsif($line =~ /^port: .*/) {
		$port = ($line =~ m/^port: (.*)$/)[0];
	} elsif($line =~ /^hostname: .*/) {
		$hostname = ($line =~ m/^hostname: (.*)$/)[0];
	} elsif($line =~ /^groups_table: .*/) {
		$groupsTableName = ($line =~ m/^groups_table: (.*)$/)[0];
	} elsif($line =~ /^users_table: .*/) {
		$usersTableName = ($line =~ m/^users_table: (.*)$/)[0];
	}
}

if(!defined($password) || !defined($username) || !defined($port) || !defined($database) || !defined($hostname) || !defined($groupsTableName) || !defined($usersTableName)) {
	print "Can't get config data from config file.\n";
	exit 14;
}

###Main Structure

# read data from the script and create a structure from it
my $fromPerun = {};
my $ID_HEADER = "ID";
my $FULL_NAME_HEADER = "FULL_NAME";
my $NAME_HEADER = "NAME";
my $DESC_HEADER = "DESCRIPTION";
my $MEMBERSHIP_HEADER = "MEMBERSHIP";

open FILE, $filename or die "Could not open $filename: $!";
while(my $line = <FILE>) {
        chomp( $line );
        my @parts = split /\t/, $line;

	my $groupId = $parts[0];
	my $groupFullName = $parts[1];
	my @splittedGroupName = split /:/, $groupFullName;
	my $groupName = $splittedGroupName[-1];
	my $groupDesc = $parts[2];
	my @groupMembership = split /,/, $parts[3];

	$fromPerun->{$groupId}->{$ID_HEADER} = $groupId;
	$fromPerun->{$groupId}->{$FULL_NAME_HEADER} = $groupFullName;
	$fromPerun->{$groupId}->{$NAME_HEADER} = $groupName;
	$fromPerun->{$groupId}->{$DESC_HEADER} = $groupDesc;
	foreach my $uco (sort @groupMembership) {
		$fromPerun->{$groupId}->{$MEMBERSHIP_HEADER}->{$uco} = $uco;
	}
}

# create a database connection
my $dbh = DBI->connect("dbi:Pg:dbname=$database;host=$hostname;port=$port",$username, $password, {AutoCommit => 0}) or die "Connect to database $database Error!\n";

#read all data from the database and prepare a structure for it
my $fromDB = {};
my $allGroups = $dbh->prepare(qq{select id, parent_id, name, description from $groupsTableName});
$allGroups->execute();
while(my $data = $allGroups->fetch) {
	my $groupId = $$data[0];
	my $groupName = $$data[2];
	my $groupDesc =  $$data[3];
	
	$fromDB->{$groupId}->{$ID_HEADER} = $groupId;
	$fromDB->{$groupId}->{$NAME_HEADER} = $groupName;
	$fromDB->{$groupId}->{$DESC_HEADER} = $groupDesc;
}

my $allMemberships = $dbh->prepare(qq{select uco, group_id from $usersTableName});
$allMemberships->execute();
while(my $data = $allMemberships->fetch) {
	my $uco = $$data[0];
	my $groupId = $$data[1];
	unless($fromDB->{$groupId}) { die "There is member with uco '$uco' and membership in group '$groupId' which does not exist in DB as object!\n"; }
	$fromDB->{$groupId}->{$MEMBERSHIP_HEADER}->{$uco} = $uco;
}

#prepare queries
my $updateGroupQuery = $dbh->prepare(qq{UPDATE $groupsTableName SET name=?, description=? where id=?});
my $insertGroupQuery = $dbh->prepare(qq{INSERT INTO $groupsTableName (id, parent_id, name, description) values (?,null,?,?)});
my $insertMembershipQuery = $dbh->prepare(qq{INSERT INTO $usersTableName (uco, group_id) values (?,?)});
my $deleteMembershipQuery = $dbh->prepare(qq{DELETE FROM $usersTableName where uco=? and group_id=?});
my $deleteAllMembershipsQuery = $dbh->prepare(qq{DELETE FROM $usersTableName where group_id=?});
my $deleteGroupQuery = $dbh->prepare(qq{DELETE FROM $groupsTableName where id=?});

#add new groups and update existing
foreach my $perunGroupId (sort keys %$fromPerun) {
	my $name = $fromPerun->{$perunGroupId}->{$NAME_HEADER};
	my $desc = $fromPerun->{$perunGroupId}->{$DESC_HEADER};

	if($fromDB->{$perunGroupId}) {
		#group exists in both, update it
		my $nameInDB = $fromDB->{$perunGroupId}->{$NAME_HEADER};
		my $descInDB = $fromDB->{$perunGroupId}->{$DESC_HEADER};
		if($name ne $nameInDB || $desc ne $descInDB) {
			#update record of group if there is any change
			$updateGroupQuery->execute($name, $desc, $perunGroupId);
			print "~~ UPDATED - group with ID $perunGroupId\n";
		}
		#check all memberships
		foreach my $ucoFromPerun (sort keys %{$fromPerun->{$perunGroupId}->{$MEMBERSHIP_HEADER}}) {
			#add missing
			unless($fromDB->{$perunGroupId}->{$MEMBERSHIP_HEADER}->{$ucoFromPerun}) {
				$insertMembershipQuery->execute($ucoFromPerun, $perunGroupId);
				print "++ ADDED - membership $ucoFromPerun to group $perunGroupId\n";
			}
		}
		foreach my $ucoFromDB (sort keys %{$fromDB->{$perunGroupId}->{$MEMBERSHIP_HEADER}}) {
			#remove not found
			unless($fromPerun->{$perunGroupId}->{$MEMBERSHIP_HEADER}->{$ucoFromDB}) {
				$deleteMembershipQuery->execute($ucoFromDB, $perunGroupId);
				print "-- REMOVED - membership $ucoFromDB from group $perunGroupId\n";
			}
		}
	} else {
		#group does not exists in DB, create it
		$insertGroupQuery->execute($perunGroupId, $name, $desc);
		print "++ CREATED - group with ID $perunGroupId\n";
		#add also all memberships
		foreach my $uco (sort keys %{$fromPerun->{$perunGroupId}->{$MEMBERSHIP_HEADER}}) {
			$insertMembershipQuery->execute($uco, $perunGroupId);
			print "++ ADDED - membership $uco to group $perunGroupId\n";
		}
	}	
}

#remove missing groups
foreach my $dbGroupId (sort keys %$fromDB) {
	unless($fromPerun->{$dbGroupId}) {
		#group does not exists in Perun, remove it
		$deleteAllMembershipsQuery->execute($dbGroupId);
		print "-- REMOVED - all memberships from group $dbGroupId\n";
		$deleteGroupQuery->execute($dbGroupId);
		print "-- DELETED - group $dbGroupId\n";
	}
}

commit $dbh;

$dbh->disconnect();

exit 0;
