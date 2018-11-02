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
use JSON qw( decode_json );

#predefined subs
sub waitForSynchronize;
sub waitForThreads;
sub startThreads;
sub processTasks;
sub processGroup;
sub processUser;
sub processResourceMail;
sub readDataAboutUsers;
sub readDataAboutActiveUsers;
sub readDataAboutGroups;
sub readDataAboutResourceMails;
sub readDataAboutResourceMailsFromO365Proxy;
sub readFacilityId;
sub barrierWait;
sub shellEscape($);

#DEBUG = 0 means no debug, DEBUG>0 means print other messages
my $DEBUG=0;

#file locks for groups and users
my $USERS_LOCK :shared;
my $GROUPS_LOCK :shared;
my $BARRIER_LOCK :shared;

#thread barrier counter
my $barrierCounter :shared = 0; #guarded by $BARRIER_LOCK

#arrays of users and groups
my @allUsers = ();
share(@allUsers);
my @allGroups = ();
share(@allGroups);

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
my $OPERATION_RESOURCE_MAIL = "resourceMail";
my $OPERATION_RESOURCE_MAIL_REMOVED = $OPERATION_RESOURCE_MAIL . "-REMOVED";
my $OPERATION_RESOURCE_MAIL_CHANGED = $OPERATION_RESOURCE_MAIL . "-CHANGED";
my $OPERATION_END = "end"; #signal end of the operation
my $OPERATION_SYNC = "synchronize"; #signal to synchronize with other threads
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
my $RES_NAME_TEXT = "RES_NAME";
my $RES_ALIAS_TEXT = "RES_ALIAS";
my $RES_EMAIL_ADDRESES_TEXT = "RES_EMAIL_ADDRESES";
my $RES_DISPLAY_NAME_TEXT = "RES_DISPLAY_NAME";
my $RES_TYPE_TEXT = "RES_TYPE";
my $RES_CAPACITY_TEXT = "RES_CAPACITY";
my $RES_ADDITIONAL_RESPONSE_TEXT = "RES_ADDITIONAL_RESPONSE";
my $RES_EXT_MEETING_MSG_TEXT = "RES_EXT_MEETING_MSG";
my $RES_ALLOW_CONFLICTS_TEXT = "RES_ALLOW_CONFLICTS";
my $RES_BOOKING_WINDOW_TEXT = "RES_BOOKING_WINDOW";
my $RES_PERCENTAGE_ALLOWED_TEXT = "RES_PERCENTAGE_ALLOWED";
my $RES_ENFORCE_SCHED_HORIZON_TEXT = "RES_ENFORCE_SCHED_HORIZON";
my $RES_MAX_CONFLICT_INSTANCES_TEXT = "RES_MAX_CONFLICT_INSTANCES";
my $RES_MAX_DURATION_TEXT = "RES_MAX_DURATION";
my $RES_SCHED_DURING_WORK_HOURS_TEXT = "RES_SCHED_DURING_WORK_HOURS";
my $RES_ALL_BOOK_IN_POLICY_TEXT = "RES_ALL_BOOK_IN_POLICY";
my $RES_ALL_REQ_IN_POLICY_TEXT = "RES_ALL_REQ_IN_POLICY";
my $RES_ALL_REQ_OUT_OF_POLICY_TEXT = "RES_ALL_REQ_OUT_OF_POLICY";
my $RES_WORKDAYS_TEXT = "RES_WORKDAYS";
my $RES_WORKING_HOURS_START_TIME_TEXT = "RES_WORKING_HOURS_START_TIME";
my $RES_WORKING_HOURS_END_TIME_TEXT = "RES_WORKING_HOURS_END_TIME";
my $RES_ALLOW_RECURRING_MEETINGS_TEXT = "RES_ALLOW_RECURRING_MEETINGS";
my $RES_ADD_ADDITIONAL_RESPONSE_TEXT = "RES_ADD_ADDITIONAL_RESPONSE";
my $RES_DELEGATES_TEXT = "RES_DELEGATES";
my $RES_BOOK_IN_POLICY_TEXT = "RES_BOOK_IN_POLICY";
my $RES_REQUEST_IN_POLICY_TEXT = "RES_REQUEST_IN_POLICY";
my $RES_REQUEST_OUT_OF_POLICY_TEXT = "RES_REQUEST_OUT_OF_POLICY";

#needed global variables and constants for this script
my $instanceName;
my $pathToServiceFile;
my $serviceName;
my $domain = "";
my $o365ConnectorFile = "./o365-connector.pl";
my $returnCode :shared;
$returnCode = 0;

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

#resource-mails data filename from perun need to exists (even if it is empty)
my $resourceMailsDataFilename = "$pathToServiceFile/$serviceName-resource-mails";
if(! -f $resourceMailsDataFilename) {
	print "ERROR - Missing service file with data about resource mails.\n";
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

#read new data about resource mails from PERUN
my $newResourceMailsStruc = readDataAboutResourceMails $resourceMailsDataFilename;

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

#read data about existing resources from o365 proxy
my $lastResourceMailsStruc = readDataAboutResourceMailsFromO365Proxy;
unless($lastResourceMailsStruc) { $lastResourceMailsStruc = {}; }

#prepare new cache files
my $newUsersCache = new File::Temp( UNLINK => 1 );
my $newGroupsCache = new File::Temp( UNLINK => 1 );
open FILE_USERS_CACHE, ">$newUsersCache" or die "Could not open file with new cache of users data $newUsersCache: $!\n";
open FILE_GROUPS_CACHE, ">$newGroupsCache" or die "Could not open file with new cache of groups data $newGroupsCache: $!\n";

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

waitForSynchronize;

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

waitForSynchronize;

#create and submit jobs for working with resource-mail's objects
foreach my $key (keys %$newResourceMailsStruc) {
	my $newResourceMail = $newResourceMailsStruc->{$key};

	my $job = { $OPERATION => $OPERATION_RESOURCE_MAIL_CHANGED, $ARGUMENT => $newResourceMail };
	
	#add job to the queue to process it by threads
	$jobQueue->enqueue($job);
}

waitForSynchronize;

#we need to also remove not existing resource from o365 proxy
foreach my $key (keys %$lastResourceMailsStruc) {
	my $newResourceMail = $newResourceMailsStruc->{$key};
	unless($newResourceMail) {
		#resource mail no longer exists, we should remove it
		my $job = { $OPERATION => $OPERATION_RESOURCE_MAIL_REMOVED, $ARGUMENT => $lastResourceMailsStruc->{$key} };
		#add job to the queue to process it by threads
		$jobQueue->enqueue($job);
	}
}

#wait for all threads to finish
waitForThreads;

#write all records to files
#IMPORTANT: there is no need for locks, because there is only 1 main thread in this part of code
foreach my $userRecord (@allUsers) {
	print FILE_USERS_CACHE $userRecord . "\n";
}

foreach my $groupRecord (@allGroups) {
	print FILE_GROUPS_CACHE $groupRecord . "\n";
}

#copy new cache files to place with old cache files
close FILE_USERS_CACHE or die "Could not close file $newUsersCache: $!\n";
close FILE_GROUPS_CACHE or die "Could not close file $newGroupsCache: $!\n";
copy( $newUsersCache, $lastStateOfUsersFilename );
copy( $newGroupsCache, $lastStateOfGroupsFilename );

exit $returnCode;

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
		} elsif ($job->{$OPERATION} eq $OPERATION_SYNC) {
			barrierWait();
		} else {
			#do the job
			if($job->{$OPERATION} =~ $OPERATION_GROUP) {
				$sucess = processGroup( $job->{$ARGUMENT} , $job->{$OPERATION} );
			} elsif ($job->{$OPERATION} =~ $OPERATION_USER) {
				$sucess = processUser( $job->{$ARGUMENT} , $job->{$OPERATION} );
			} elsif ($job->{$OPERATION} =~ $OPERATION_RESOURCE_MAIL) {
				$sucess = processResourceMail( $job->{$ARGUMENT}, $job->{$OPERATION} );
			} else {
				print "ERROR - UNKNOWN OPERATION: " . $job->{$OPERATION} . " was skipped!\n";
				$sucess = 0;
			}
		}
		
		#if this process is not success, set return code for script to not 0
		unless($sucess) {
			$returnCode=1;
		}
	}

}

#method to set barrier for threads
sub barrierWait {
	lock $BARRIER_LOCK;
	$barrierCounter++;

	if($barrierCounter == $THREAD_COUNT) {
		$barrierCounter = 0;
		cond_broadcast($BARRIER_LOCK);
	} else {
		cond_wait($BARRIER_LOCK);
	}
}

#Sub to wait for every running thread and synchronize them
sub waitForSynchronize {
	#send special job to queue to signal that all threads should wait for others to synchronize
	for(1 .. $THREAD_COUNT) {
		$jobQueue->enqueue( { $OPERATION => $OPERATION_SYNC } );
	}
}

#Sub to wait for every running thread and send terminate operation for all of them
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

#Sub to process group with O365 connector and if success, add it to the cache file
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
			lock $GROUPS_LOCK;
			push @allGroups, $groupObject->{$PLAIN_TEXT_OBJECT_TEXT};
		}
		if($DEBUG) { print "CHANGE GROUP N-EQ: " . $groupObject->{$AD_GROUP_NAME_TEXT} . " - OK\n" };
	} elsif( $localOperation eq $OPERATION_GROUP_NOT_CHANGED ) {
		if($DEBUG) { print "CHANGE GROUP EQ: " . $groupObject->{$AD_GROUP_NAME_TEXT} . " - STARTED\n"; }
		{
			lock $GROUPS_LOCK;
			push @allGroups, $groupObject->{$PLAIN_TEXT_OBJECT_TEXT};
		}
		if($DEBUG) { print "CHANGE GROUP EQ: " . $groupObject->{$AD_GROUP_NAME_TEXT} . " - OK\n" };
	} else {
		print "ERROR - UNKNOWN OPERATION: " . $localOperation . " was skipped for group " . $groupObject->{$AD_GROUP_NAME_TEXT} . "\n";
		return 0;
	}
	
	return 1;
}

#Sub to process resource-mail with O365 connector and if success, add it to the cache file
sub processResourceMail {
	my $resourceMailObject = shift;
	my $localOperation = shift;

	if( $localOperation eq $OPERATION_RESOURCE_MAIL_CHANGED ) {

		my $command = $o365ConnectorFile . " -s " . shellEscape($serviceName) . " -S " . shellEscape($instanceName) . " -c Set-MuniResource" . " -i " . shellEscape $resourceMailObject->{$RES_NAME_TEXT};
		if($resourceMailObject->{$RES_ALIAS_TEXT}) { $command = $command . " -A " . shellEscape $resourceMailObject->{$RES_ALIAS_TEXT}; }
		my $emailAddresses = join " ", map { shellEscape $_ } @{$resourceMailObject->{$RES_EMAIL_ADDRESES_TEXT}};
		if($emailAddresses) { $command = $command . " -B " . $emailAddresses };
		if($resourceMailObject->{$RES_DISPLAY_NAME_TEXT}) { $command = $command . " -C " . shellEscape $resourceMailObject->{$RES_DISPLAY_NAME_TEXT}; }
		if($resourceMailObject->{$RES_TYPE_TEXT}) { $command = $command . " -D " . shellEscape $resourceMailObject->{$RES_TYPE_TEXT}; }
		if($resourceMailObject->{$RES_CAPACITY_TEXT}) { $command = $command . " -E " . shellEscape $resourceMailObject->{$RES_CAPACITY_TEXT}; }
		if($resourceMailObject->{$RES_ADDITIONAL_RESPONSE_TEXT}) { $command = $command . " -F " . shellEscape $resourceMailObject->{$RES_ADDITIONAL_RESPONSE_TEXT}; }
		if($resourceMailObject->{$RES_EXT_MEETING_MSG_TEXT}) { $command = $command . " -G " . shellEscape $resourceMailObject->{$RES_EXT_MEETING_MSG_TEXT}; }
		if($resourceMailObject->{$RES_ALLOW_CONFLICTS_TEXT}) { $command = $command . " -H " . shellEscape $resourceMailObject->{$RES_ALLOW_CONFLICTS_TEXT}; }
		if($resourceMailObject->{$RES_BOOKING_WINDOW_TEXT}) { $command = $command . " -I " . shellEscape $resourceMailObject->{$RES_BOOKING_WINDOW_TEXT}; }
		if($resourceMailObject->{$RES_PERCENTAGE_ALLOWED_TEXT}) { $command = $command . " -J " . shellEscape $resourceMailObject->{$RES_PERCENTAGE_ALLOWED_TEXT}; }
		if($resourceMailObject->{$RES_ENFORCE_SCHED_HORIZON_TEXT}) { $command = $command . " -K " . shellEscape $resourceMailObject->{$RES_ENFORCE_SCHED_HORIZON_TEXT}; }
		if($resourceMailObject->{$RES_MAX_CONFLICT_INSTANCES_TEXT}) { $command = $command . " -L " . shellEscape $resourceMailObject->{$RES_MAX_CONFLICT_INSTANCES_TEXT}; }
		if($resourceMailObject->{$RES_MAX_DURATION_TEXT}) { $command = $command . " -M " . shellEscape $resourceMailObject->{$RES_MAX_DURATION_TEXT}; }
		if($resourceMailObject->{$RES_SCHED_DURING_WORK_HOURS_TEXT}) { $command = $command . " -N " . shellEscape $resourceMailObject->{$RES_SCHED_DURING_WORK_HOURS_TEXT}; }
		if($resourceMailObject->{$RES_ALL_BOOK_IN_POLICY_TEXT}) { $command = $command . " -O " . shellEscape $resourceMailObject->{$RES_ALL_BOOK_IN_POLICY_TEXT}; }
		if($resourceMailObject->{$RES_ALL_REQ_IN_POLICY_TEXT}) { $command = $command . " -P " . shellEscape $resourceMailObject->{$RES_ALL_REQ_IN_POLICY_TEXT}; }
		if($resourceMailObject->{$RES_ALL_REQ_OUT_OF_POLICY_TEXT}) { $command = $command . " -Q " . shellEscape $resourceMailObject->{$RES_ALL_REQ_OUT_OF_POLICY_TEXT}; }
		my $workingDays = join " ", map { shellEscape $_ } @{$resourceMailObject->{$RES_WORKDAYS_TEXT}};
		if($workingDays) { $command = $command . " -R " . $workingDays; }
		if($resourceMailObject->{$RES_WORKING_HOURS_START_TIME_TEXT}) { $command = $command . " -T " . shellEscape $resourceMailObject->{$RES_WORKING_HOURS_START_TIME_TEXT}; }
		if($resourceMailObject->{$RES_WORKING_HOURS_END_TIME_TEXT}) { $command = $command . " -U " . shellEscape $resourceMailObject->{$RES_WORKING_HOURS_END_TIME_TEXT}; }
		if($resourceMailObject->{$RES_ALLOW_RECURRING_MEETINGS_TEXT}) { $command = $command . " -V " . shellEscape $resourceMailObject->{$RES_ALLOW_RECURRING_MEETINGS_TEXT}; }
		if($resourceMailObject->{$RES_ADD_ADDITIONAL_RESPONSE_TEXT}) { $command = $command . " -X " . shellEscape $resourceMailObject->{$RES_ADD_ADDITIONAL_RESPONSE_TEXT}; }
		my $delegates = join " ", map { shellEscape $_ } @{$resourceMailObject->{$RES_DELEGATES_TEXT}};
		if($delegates) { $command = $command . " -Y " . $delegates; }
		my $bookInPolicy = join " ", map { shellEscape $_ } @{$resourceMailObject->{$RES_BOOK_IN_POLICY_TEXT}};
		if($bookInPolicy) { $command = $command . " -Z " . $bookInPolicy; }
		my $reqInPolicy = join " ", map { shellEscape $_ } @{$resourceMailObject->{$RES_REQUEST_IN_POLICY_TEXT}};
		if($reqInPolicy) { $command = $command . " -x " . $reqInPolicy; }
		my $reqOutOfPolicy = join " ", map { shellEscape $_ } @{$resourceMailObject->{$RES_REQUEST_OUT_OF_POLICY_TEXT}};
		if($reqOutOfPolicy) { $command = $command . " -y " . $reqOutOfPolicy; }
		
		if($DEBUG) { print "CHANGE RESOURCE-MAIL: " . $resourceMailObject->{$RES_NAME_TEXT} . " - STARTED\n"; }
		`$command`;
		if($@) { 
			print "CHANGE RESOURCE-MAIL: " . $resourceMailObject->{$RES_NAME_TEXT} . " - ERROR - $@\n";
			return 0; 
		}
		if($DEBUG) { print "CHANGE RESOURCE-MAIL: " . $resourceMailObject->{$RES_NAME_TEXT} . " - OK\n" };
	} elsif( $localOperation eq $OPERATION_RESOURCE_MAIL_REMOVED ) {
		my $command = $o365ConnectorFile . " -s " . shellEscape($serviceName) . " -S " . shellEscape($instanceName) . " -c Remove-MuniResource" . " -i " . shellEscape $resourceMailObject->{$RES_NAME_TEXT};
		if($DEBUG) { print "REMOVE RESOURCE-MAIL: " . $resourceMailObject->{$RES_NAME_TEXT} . " - STARTED\n"; }
		`$command`;
		if($?) { 
			print "REMOVE RESOURCE-MAIL: " . $resourceMailObject->{$RES_NAME_TEXT} . " - ERROR\n";
			return 0; 
		}
		if($DEBUG) { print "REMOVE RESOURCE-MAIL N-EQ: " . $resourceMailObject->{$RES_NAME_TEXT} . " - OK\n" };
	} else {
		print "ERROR - UNKNOWN OPERATION: " . $localOperation . " was skipped for resource-mail " . $resourceMailObject->{$RES_NAME_TEXT} . "\n";
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
			lock $USERS_LOCK;
			push @allUsers, $userObject->{$PLAIN_TEXT_OBJECT_TEXT};
		}
		if($DEBUG) { print "CHANGE USER N-EQ: " . $userObject->{$UPN_TEXT} . " - OK\n"; }
	} elsif( $localOperation eq $OPERATION_USER_NOT_CHANGED ) {
		if($DEBUG) { print "CHANGE USER EQ: " . $userObject->{$UPN_TEXT} . " - STARTED\n"; }
		{
			lock $USERS_LOCK;
			push @allUsers, $userObject->{$PLAIN_TEXT_OBJECT_TEXT};
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

#Sub to read data about resource-mails from file and convert it to perl hash
sub readDataAboutResourceMails {
	my $pathToFile = shift;

	my $resourceMailsStruc = {};
	open FILE, $pathToFile or die "Could not open file with resource-mails data from perun $pathToFile: $!\n";

	while(my $line = <FILE>) {
		chomp( $line );
		my @parts = split /\t/, $line;
		my $resourceMailName = $parts[0];
		my $resourceAlias = $parts[1];
		my @resourceEmails = ();
		if($parts[2]) { @resourceEmails = split / /, $parts[2]; }
		my $resourceDisplayName = $parts[3];
		my $resourceType = $parts[4];
		my $resourceCapacity = $parts[5];
		my $resourceAdditionalResponse = $parts[6];
		my $resourceExtMeetingMsg = $parts[7];
		my $resourceAllowConflicts = $parts[8];
		my $resourceBookingWindow = $parts[9];
		my $resourcePercentageAllowed = $parts[10];
		my $resourceEnforceSchedHorizon = $parts[11];
		my $resourceMaxConflictInstances = $parts[12];
		my $resourceMaxDuration = $parts[13];
		my $resourceSchedDuringWorkHours = $parts[14];
		my $resourceAllBookInPolicy = $parts[15];
		my $resourceAllReqInPolicy = $parts[16];
		my $resourceAllReqOutOfPolicy = $parts[17];
		my @resourceWorkdays = ();
		if($parts[18]) { @resourceWorkdays = split / /, $parts[18]; }
		my $resourceWorkingHoursStartTime = $parts[19];
		my $resourceWorkingHoursEndTime = $parts[20];
		my $resourceAllowRecurringMeetings = $parts[21];
		my $resourceAddAdditionalResponse = $parts[22];
		my @resourceDelegates = ();
		if($parts[23]) { @resourceDelegates = split / /, $parts[23]; }
		my @resourceBookInPolicy = ();
		if($parts[24]) { @resourceBookInPolicy = split / /, $parts[24]; }
		my @resourceRequestInPolicy = ();
		if($parts[25]) { @resourceRequestInPolicy = split / /, $parts[25]; }
		my @resourceRequestOutOfPolicy = ();
		if($parts[26]) { @resourceRequestOutOfPolicy = split / /, $parts[26]; }

		#if resource-mail name is from any reason empty, set global return code to 1 and skip this resource-mail
		unless($line) {
			print "ERROR - Can't find name of resource-mail in $pathToFile for line '$line'\n";
			$returnCode = 1;
			next;
		}

		$resourceMailsStruc->{$resourceMailName}->{$RES_NAME_TEXT} = $resourceMailName;
		$resourceMailsStruc->{$resourceMailName}->{$RES_ALIAS_TEXT} = $resourceAlias;
		$resourceMailsStruc->{$resourceMailName}->{$RES_EMAIL_ADDRESES_TEXT} = \@resourceEmails;
		$resourceMailsStruc->{$resourceMailName}->{$RES_DISPLAY_NAME_TEXT} = $resourceDisplayName;
		$resourceMailsStruc->{$resourceMailName}->{$RES_TYPE_TEXT} = $resourceType;
		$resourceMailsStruc->{$resourceMailName}->{$RES_CAPACITY_TEXT} = $resourceCapacity;
		$resourceMailsStruc->{$resourceMailName}->{$RES_ADDITIONAL_RESPONSE_TEXT} = $resourceAdditionalResponse;
		$resourceMailsStruc->{$resourceMailName}->{$RES_EXT_MEETING_MSG_TEXT} = $resourceExtMeetingMsg;
		$resourceMailsStruc->{$resourceMailName}->{$RES_ALLOW_CONFLICTS_TEXT} = $resourceAllowConflicts;
		$resourceMailsStruc->{$resourceMailName}->{$RES_BOOKING_WINDOW_TEXT} = $resourceBookingWindow;
		$resourceMailsStruc->{$resourceMailName}->{$RES_PERCENTAGE_ALLOWED_TEXT} = $resourcePercentageAllowed;
		$resourceMailsStruc->{$resourceMailName}->{$RES_ENFORCE_SCHED_HORIZON_TEXT} = $resourceEnforceSchedHorizon;
		$resourceMailsStruc->{$resourceMailName}->{$RES_MAX_CONFLICT_INSTANCES_TEXT} = $resourceMaxConflictInstances;
		$resourceMailsStruc->{$resourceMailName}->{$RES_MAX_DURATION_TEXT} = $resourceMaxDuration;
		$resourceMailsStruc->{$resourceMailName}->{$RES_SCHED_DURING_WORK_HOURS_TEXT} = $resourceSchedDuringWorkHours;
		$resourceMailsStruc->{$resourceMailName}->{$RES_ALL_BOOK_IN_POLICY_TEXT} = $resourceAllBookInPolicy;
		$resourceMailsStruc->{$resourceMailName}->{$RES_ALL_REQ_IN_POLICY_TEXT} = $resourceAllReqInPolicy;
		$resourceMailsStruc->{$resourceMailName}->{$RES_ALL_REQ_OUT_OF_POLICY_TEXT} = $resourceAllReqOutOfPolicy;
		$resourceMailsStruc->{$resourceMailName}->{$RES_WORKDAYS_TEXT} = \@resourceWorkdays;
		$resourceMailsStruc->{$resourceMailName}->{$RES_WORKING_HOURS_START_TIME_TEXT} = $resourceWorkingHoursStartTime;
		$resourceMailsStruc->{$resourceMailName}->{$RES_WORKING_HOURS_END_TIME_TEXT} = $resourceWorkingHoursEndTime;
		$resourceMailsStruc->{$resourceMailName}->{$RES_ALLOW_RECURRING_MEETINGS_TEXT} = $resourceAllowRecurringMeetings;
		$resourceMailsStruc->{$resourceMailName}->{$RES_ADD_ADDITIONAL_RESPONSE_TEXT} = $resourceAddAdditionalResponse;
		$resourceMailsStruc->{$resourceMailName}->{$RES_DELEGATES_TEXT} = \@resourceDelegates;
		$resourceMailsStruc->{$resourceMailName}->{$RES_BOOK_IN_POLICY_TEXT} = \@resourceBookInPolicy;
		$resourceMailsStruc->{$resourceMailName}->{$RES_REQUEST_IN_POLICY_TEXT} = \@resourceRequestInPolicy;
		$resourceMailsStruc->{$resourceMailName}->{$RES_REQUEST_OUT_OF_POLICY_TEXT} = \@resourceRequestOutOfPolicy;
		$resourceMailsStruc->{$resourceMailName}->{$PLAIN_TEXT_OBJECT_TEXT} = $line;
	}
	close FILE or die "Could not close file $pathToFile: $!\n";

	return $resourceMailsStruc;
}

#Sub to read data about existing resource from o365 proxy
sub readDataAboutResourceMailsFromO365Proxy {
	my $resourceMailsStruc = {};

	my $command = $o365ConnectorFile . " -s " . shellEscape($serviceName)  . " -S " . shellEscape($instanceName) . " -c Get-MuniResources";
	my $result = `$command`;
	my $error = $?;
	if($error) {
		die "GET MUNI RESOURCES - ERROR with status code $error\n";
	}

	my $resourceStructureFromO365 = decode_json( $result );
	
	foreach my $resource (@$resourceStructureFromO365) {
		my $resourceIdentity = $resource->{'Identity'};
		#strip part after '@' from identity
		$resourceIdentity =~ s/@.*//g;
		$resourceMailsStruc->{$resourceIdentity} = $resource;
		$resourceMailsStruc->{$resourceIdentity}->{$RES_NAME_TEXT} = $resourceIdentity;
	}

	return $resourceMailsStruc;
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
