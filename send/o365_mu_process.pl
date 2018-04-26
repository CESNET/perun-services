#!/usr/bin/perl

use strict;
use warnings;
use threads;
use threads::shared;
use Thread::Queue;
use DBI;
use Getopt::Long qw(:config no_ignore_case);
use File::Temp qw/ tempfile tempdir /;
use File::Copy;
use File::Path qw(make_path);
use Data::Dumper;

#predefined subs
sub waitForThreads;
sub startThreads;
sub processTasks;
sub processGroup;
sub processUser;
sub readDataAboutUsers;
sub readDataAboutActiveUsers;
sub readDataAboutGroups;
sub readFacilityId;
sub shellEscape($);

#DEBUG = 0 means no debug, DEBUG>0 means print other messages
my $DEBUG=0;

#file locks for groups and users
my $FILE_USERS_LOCK :shared;
my $FILE_GROUPS_LOCK :shared;

#number of worker threads
my $THREAD_COUNT = 10;

#constants for jobs 
my $OPERATION = "operation";
my $OPERATION_USER = "user";
my $OPERATION_USER_CHANGED = $OPERATION_USER . "-CHANGED";
my $OPERATION_USER_NOT_CHANGED = $OPERATION_USER . "-NOT_CHANGED";
my $OPERATION_GROUP = "group";
my $OPERATION_GROUP_CHANGED = $OPERATION_GROUP . "-CHANGED";
my $OPERATION_GROUP_NOT_CHANGED = $OPERATION_GROUP . "-NOT_CHANGED";
my $OPERATION_END = "end"; #signal end of the operation
my $ARGUMENT = "argument";

#text predefined constants to use
my $UPN_TEXT = "upn";
my $DELIVERED_TO_MAILBOX_AND_FORWARD_TEXT = "deliverToMailBoxAndForward";
my $FORWARDING_SMTP_ADDRESS_TEXT = "forwardingSmtpAdress";
my $ARCHIVE_TEXT = "archive";
my $EMAIL_ADDRESSES_TEXT = "emailAddresses";
my $PLAIN_TEXT_OBJECT_TEXT = "plainTextObject";
my $AD_GROUP_NAME_TEXT = "adGroupName";
my $SEND_AS_TEXT = "sendAs";

#needed global variables and constants for this script
my $instanceName;
my $pathToServiceFile;
my $serviceName;
my $domain = "";
my $o365ConnectorFile = "./o365-connector.pl";
my $returnCode=0;

#get options from input of script
GetOptions ("instanceName|i=s" => \$instanceName, "pathToServiceFile|p=s" => \$pathToServiceFile, "serviceName|s=s" => \$serviceName);

#check mandatory parameters
#instance name is mandatory parameter
if(!defined $instanceName) {
	print "ERROR - Missing DBNAME to process service.\n";
	exit 10;
}

#pathToServiceFile is mandatory parameter
if(!defined $pathToServiceFile) {
	print "ERROR - Missing path to file with generated data to process service.\n";
	exit 11;
}

#name of service is mandatory parameter
if(!defined $serviceName) {
	print "ERROR - Missing info about service name to process service.\n";
	exit 12;
}

#user data filename from perun need to exists (even if it is empty)
my $usersDataFilename = "$pathToServiceFile/$serviceName-users";
if(! -f $usersDataFilename) {
	print "ERROR - Missing service file with data about users.\n";
	exit 13;
}

#group data filename from perun need to exists (even if it is empty)
my $groupsDataFilename = "$pathToServiceFile/$serviceName-groups";
if(! -f $groupsDataFilename) {
	print "ERROR - Missing service file with data about groups.\n";
	exit 14;
}

#file with facility id from gen (can't be empty)
my $facilityIdFilename = "$pathToServiceFile/$serviceName-facilityId";
if(! -f $facilityIdFilename) {
  print "ERORR - Missing file with facilit id.\n";
  exit 15;
}

#read facility id from file
my $facilityId = readFacilityId $facilityIdFilename;

#prepare paths to files with cache (users and groups cache)
my $basicCacheDir = "/var/cache/perun/services/$facilityId/$serviceName/";
my $cacheDir = $basicCacheDir . "/" . $instanceName . "/";
make_path($cacheDir, { chmod => 0755, error => \my $err });
if(@$err) {
	print "ERROR - Can't create whole cache directory $cacheDir.\n";
	exit 16;
}
my $lastStateOfUsersFilename = $cacheDir . "o365_mu-users";
my $lastStateOfGroupsFilename = $cacheDir . "o365_mu-groups";

#file with active users need to exists
my $pathToActiveUsersFile = $basicCacheDir . "activeO365Users";
if(! -f $pathToActiveUsersFile) {
	print "ERORR - Missing file with list of active o365 users.\n";
	exit 17;
}

#read data from files and convert them to the hash structure in perl
#read new data about users from PERUN
my $newUsersStruc = readDataAboutUsers $usersDataFilename;

#read new data about groups from PERUN
my $newGroupsStruc = readDataAboutGroups $groupsDataFilename;

#Read active users from file
my $activeUsers = readDataAboutActiveUsers $pathToActiveUsersFile;

#Read data (cache) about last state of users
my $lastUsersStruc = {};
if( -f $lastStateOfUsersFilename) { 
	$lastUsersStruc = readDataAboutUsers $lastStateOfUsersFilename; 
}

#Read data (cache) about last state of groups
my $lastGroupsStruc = {};
if( -f $lastStateOfGroupsFilename) {
	$lastGroupsStruc = readDataAboutGroups $lastStateOfGroupsFilename;
}

#prepare new cache files
my $newUsersCache = new File::Temp( UNLINK => 1 );
my $newGroupsCache = new File::Temp( UNLINK => 1 );
open FILE_USERS_CACHE, ">$newUsersCache" or die "Could not open file with new cache of users data $newUsersCache: $!\n";
open FILE_GROUPS_CACHE, ">$newGroupsCache" or die "Could not open file with new cache of users data $newGroupsCache: $!\n";

#prepare threads for work jobs
my $jobQueue = Thread::Queue->new();
#start threads to do their jobs
startThreads;

#create and submit jobs for working with user's objects
foreach my $key (keys %$newUsersStruc) {
	my $newUser = $newUsersStruc->{$key};
	my $oldUser = $lastUsersStruc->{$key};
	#if user is not active in AD, skip him
	unless($activeUsers->{$key}) { next; }

	my $job;
	unless($oldUser) {
		#user is new, add him
		$job = { $OPERATION => $OPERATION_USER_CHANGED, $ARGUMENT => $newUser };
	} else {
		if($newUser->{$PLAIN_TEXT_OBJECT_TEXT} eq $oldUser->{$PLAIN_TEXT_OBJECT_TEXT}) {
			#user exists and he is equals, just write his data to the cache file
			$job = { $OPERATION => $OPERATION_USER_NOT_CHANGED, $ARGUMENT => $newUser };
		} else {
			#user eixsts but he is different, modify him (add and modify operation is the same there)
			$job = { $OPERATION => $OPERATION_USER_CHANGED, $ARGUMENT => $newUser };
		}
	}
	#add job to the queue to process it by threads
	$jobQueue->enqueue($job);
}

#create and submit jobs for working with group's objets
foreach my $key (keys %$newGroupsStruc) {
	my $newGroup = $newGroupsStruc->{$key};
	my $oldGroup = $lastGroupsStruc->{$key};
	
	#remove not active users from sendAs of the new group
	$newGroup->{$SEND_AS_TEXT} = [ grep { $activeUsers->{$_}  }  @{$newGroup->{$SEND_AS_TEXT}} ];
	$newGroup->{$PLAIN_TEXT_OBJECT_TEXT} = $key . "\t" . join " ", @{$newGroup->{$SEND_AS_TEXT}};

	my $job;
	unless($oldGroup) {
		#group is new, add it
		$job = { $OPERATION => $OPERATION_GROUP_CHANGED, $ARGUMENT => $newGroup };
	} else {
		if($newGroup->{$PLAIN_TEXT_OBJECT_TEXT} eq $oldGroup->{$PLAIN_TEXT_OBJECT_TEXT}) {
			#group exists and it is equals, just write it's data to the cache file
			$job = { $OPERATION => $OPERATION_GROUP_NOT_CHANGED, $ARGUMENT => $newGroup };
		} else {
			#group exists but it is different, modify it (add and modify operation is the same there)
			$job = { $OPERATION => $OPERATION_GROUP_CHANGED, $ARGUMENT => $newGroup };
		}
	}
	#add job to the queue to process it by threads
	$jobQueue->enqueue($job);
}

#wait for all threads to finish
waitForThreads;

#copy new cache files to place with old cache files
close FILE_USERS_CACHE or die "Could not close file $newUsersCache: $!\n";
close FILE_GROUPS_CACHE or die "Could not close file $newGroupsCache: $!\n";;
copy( $newUsersCache, $lastStateOfUsersFilename );
copy( $newGroupsCache, $lastStateOfGroupsFilename );

return $returnCode;

#---------------------------------SUBS------------------------------------

#Sub to start all threads
sub startThreads {
	for(1 .. $THREAD_COUNT) {
		threads->create(\&processTasks);
	}
}

#Sub to process one job from queue of jobs
sub processTasks {
	my $running = 1;
	my $sucess = 1;
	while($running) {
		my $job = $jobQueue->dequeue;

		if($job->{$OPERATION} eq $OPERATION_END) {
			$running = 0;
		} else {
			#do the job
			if($job->{$OPERATION} =~ $OPERATION_GROUP) {
				$sucess = processGroup( $job->{$ARGUMENT} , $job->{$OPERATION} );
			} elsif ($job->{$OPERATION} =~ $OPERATION_USER) {
				$sucess = processUser( $job->{$ARGUMENT} , $job->{$OPERATION} );
			} else {
				print "ERROR - UNKNOWN OPERATION: " . $job->{$OPERATION} . " was skipped!\n";
				$sucess = 0;
			}
		}
	}

	#if this process is not success, set return code for script to not 0
	unless($sucess) {
		$returnCode=1;
	}
}

#Sub to send end operation for every running thread
sub waitForThreads {
	#send special job to queue to signal the thread to terminate
	for(1 .. $THREAD_COUNT) {
		$jobQueue->enqueue( { $OPERATION => $OPERATION_END } );
	}

	#wait for all threads to finish work
	foreach my $thr (threads->list()) {
		$thr->join();
	}
}

#Sub to process group with O365 connector and if success, add him to the cache file
sub processGroup {
	my $groupObject = shift;
	my $localOperation = shift;

	if( $localOperation eq $OPERATION_GROUP_CHANGED ) {
		my $command = $o365ConnectorFile . " -s " . shellEscape($serviceName)  . " -S " . shellEscape($instanceName) . " -c Set-MuniGroup" . " -i " . shellEscape $groupObject->{$AD_GROUP_NAME_TEXT};
		my $sendAsMails = join " ", map { shellEscape $_ } @{$groupObject->{$SEND_AS_TEXT}} ;
		if($sendAsMails) {
			$command = $command . " -t " . $sendAsMails;
		}

		if($DEBUG) { print "CHANGE GROUP N-EQ: " . $groupObject->{$AD_GROUP_NAME_TEXT} . " - STARTED\n"; }
		`$command`;
		if($?) { 
			print "CHANGE GROUP N-EQ: " . $groupObject->{$AD_GROUP_NAME_TEXT} . " - ERROR\n";
			return 0; 
		}
		{
			lock $FILE_GROUPS_LOCK;
			print FILE_GROUPS_CACHE $groupObject->{$PLAIN_TEXT_OBJECT_TEXT} . "\n";
		}
		if($DEBUG) { print "CHANGE GROUP N-EQ: " . $groupObject->{$AD_GROUP_NAME_TEXT} . " - OK\n" };
	} elsif( $localOperation eq $OPERATION_GROUP_NOT_CHANGED ) {
		if($DEBUG) { print "CHANGE GROUP EQ: " . $groupObject->{$AD_GROUP_NAME_TEXT} . " - STARTED\n"; }
		{
			lock $FILE_GROUPS_LOCK;
			print FILE_GROUPS_CACHE $groupObject->{$PLAIN_TEXT_OBJECT_TEXT} . "\n";
		}
		if($DEBUG) { print "CHANGE GROUP EQ: " . $groupObject->{$AD_GROUP_NAME_TEXT} . " - OK\n" };
	} else {
		print "ERROR - UNKNOWN OPERATION: " . $localOperation . " was skipped for group " . $groupObject->{$AD_GROUP_NAME_TEXT} . "\n";
		return 0;
	}
	
	return 1;
}

#Sub to process user with O365 connector and if success, add him to the cache file
sub processUser {
	my $userObject = shift;
	my $localOperation = shift;

	if( $localOperation eq $OPERATION_USER_CHANGED ) {
		my $command = $o365ConnectorFile . " -s " . shellEscape($serviceName)  . " -S " . shellEscape($instanceName) . " -c Set-MuniMailBox " . " -i " . shellEscape($userObject->{$UPN_TEXT}) . " -a " . shellEscape($userObject->{$ARCHIVE_TEXT}) . " -d " . shellEscape($userObject->{$DELIVERED_TO_MAILBOX_AND_FORWARD_TEXT}) . " -e " . shellEscape($userObject->{$EMAIL_ADDRESSES_TEXT});
		if($userObject->{$FORWARDING_SMTP_ADDRESS_TEXT}) {
			$command = $command . " -f " . shellEscape $userObject->{$FORWARDING_SMTP_ADDRESS_TEXT};
		}

		if($DEBUG) { print "CHANGE USER N-EQ: " . $userObject->{$UPN_TEXT} . " - STARTED\n"; }
		`$command`;
		if($?) {
			print "CHANGE USER N-EQ: " . $userObject->{$UPN_TEXT} . " - ERROR\n"; 
			return 0; 
		}
		{
			lock $FILE_USERS_LOCK;
			print FILE_USERS_CACHE $userObject->{$PLAIN_TEXT_OBJECT_TEXT} . "\n";
		}
		if($DEBUG) { print "CHANGE USER N-EQ: " . $userObject->{$UPN_TEXT} . " - OK\n"; }
	} elsif( $localOperation eq $OPERATION_USER_NOT_CHANGED ) {
		if($DEBUG) { print "CHANGE USER EQ: " . $userObject->{$UPN_TEXT} . " - STARTED\n"; }
		{
			lock $FILE_USERS_LOCK;
			print FILE_USERS_CACHE $userObject->{$PLAIN_TEXT_OBJECT_TEXT} . "\n";
		}
		if($DEBUG) { print "CHANGE USER EQ: " . $userObject->{$UPN_TEXT} . " - OK\n"; }
	} else {
		print "ERROR - UNKNOWN OPERATION: " . $localOperation . " was skipped for user " . $userObject->{$UPN_TEXT} . "\n";
		return 0;
	}

	return 1;
}

#Sub to read data about users from file and convert it to perl hash
sub readDataAboutUsers {
	my $pathToFile = shift;

	my $usersStruc = {};
	open FILE, $pathToFile or die "Could not open file with users data $pathToFile: $!\n";
	while(my $line = <FILE>) {
		chomp( $line );
		my @parts = split /\t/, $line;
		my $UPN = $parts[0];
		unless($domain) { 
			$domain = $UPN;
			$domain =~ s/^.*@//;
		}

		#If UPN is from any reason empty, set global return code to 1 and skip this user
		unless($UPN) { 
			print "ERROR - Can't find UPN for user in $pathToFile for line '$line'\n";
			$returnCode = 1;
			next;
		}
		$usersStruc->{$UPN}->{$UPN_TEXT} = $UPN;
		$usersStruc->{$UPN}->{$FORWARDING_SMTP_ADDRESS_TEXT} = $parts[1];
		$usersStruc->{$UPN}->{$ARCHIVE_TEXT} = $parts[2];
		$usersStruc->{$UPN}->{$DELIVERED_TO_MAILBOX_AND_FORWARD_TEXT} = $parts[3];
		$usersStruc->{$UPN}->{$EMAIL_ADDRESSES_TEXT} = $parts[4];
		$usersStruc->{$UPN}->{$PLAIN_TEXT_OBJECT_TEXT} = $line ;
	}
	close FILE or die "Could not close file $pathToFile: $!\n";

	return $usersStruc;
}

#Sub to read data about active users from file and convert it to perl hash
sub readDataAboutActiveUsers {
	my $pathToFile = shift;

	my $activeUsersStruc = {};
	open FILE, $pathToFile or die "Could not open file with active users $pathToFile: $!\n";
	while(my $line = <FILE>) {
		chomp( $line );
		#If ID is from any reason empty, set global return code to 1 and skip this user
		unless($line) { 
			print "ERROR - Can't find ID of active user in $pathToFile for line '$line'\n";
			$returnCode = 1;
			next;
		}
		my $id = $line . "@" . $domain;
		$activeUsersStruc->{$id} = 1;
	}
	close FILE or die "Could not close file $pathToFile: $!\n";

	return $activeUsersStruc;
}

#Sub to read data about groups from file and convert it to perl hash
sub readDataAboutGroups {
	my $pathToFile = shift;

	my $groupsStruc = {};
	open FILE, $pathToFile or die "Could not open file with groups data from perun $pathToFile: $!\n";
	while(my $line = <FILE>) {
		chomp( $line );
		my @parts = split /\t/, $line;
		my $groupADName = $parts[0];
		my @emails = ();
		if($parts[1]) { @emails = split / /, $parts[1]; }
	
		#If groupADName is from any reason empty, set global return code to 1 and skip this group
		unless($line) { 
			print "ERROR - Can't find AD name of group in $pathToFile for line '$line'\n";
			$returnCode = 1;
			next;
		}

		$groupsStruc->{$groupADName}->{$AD_GROUP_NAME_TEXT} = $groupADName;
		$groupsStruc->{$groupADName}->{$SEND_AS_TEXT} = \@emails;
		$groupsStruc->{$groupADName}->{$PLAIN_TEXT_OBJECT_TEXT} = $line;
	}
	close FILE or die "Could not close file $pathToFile: $!\n";

	return $groupsStruc;
}

#Sub to read data about facility id from file
sub readFacilityId {
	my $pathToFile = shift;

	my $facId;
	open FILE, $pathToFile or die "Could not open file with groups data from perun $pathToFile: $!\n";
	while(my $line = <FILE>) {
		chomp( $line );
		unless($facId) {
			$facId = $line;
		} else {
			die "There is more than one line in file with facility ids $pathToFile!\n";
		}
	}

	unless($facId) {
		die "Facility Id can't be obtain from file $pathToFile, it seems to be empty!\n";
	}
	return $facId;
}

#Escape all shell special characters from input
sub shellEscape($) {
	$_ = shift;

	s/([-!\@\#\$\^&\*\(\)\{\}\[\]\\\/+=\.\<\>\?;:"',`\|%\s])/\\$1/g;

	$_;
}
