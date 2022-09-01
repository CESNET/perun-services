#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);
use File::Temp qw/ tempfile tempdir /;
use File::Copy;
use File::Path qw(make_path);
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Headers;
use MIME::Base64;
use URI;
use JSON;
use Data::Dumper;
use POSIX qw(strftime);
use Encode qw(decode_utf8);

#predefined subs
sub checkParameterIsNotNull;
sub checkFileExists;
sub readFacilityId;
sub readDataAboutUsers;
sub readDataAboutGroups;
sub addObjectToCache;
sub getConfiguration;
sub getUsersContent;
sub getGroupsContent;
sub makeRequestToServer;
sub callServerForUpdate;
sub checkServerResponseStatus;
sub getResponoseContentJSON;
sub transformResultToMap;
sub createChunksForStruc;

#We want to have data in UTF8 on output
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

#-------------------------------------------------------------------------
#-----------------------------DEBBUGING-----------------------------------
#-------------------------------------------------------------------------

#DEBUG
# = 0 no debug
# = 1 info
# > 1 trace
our $DEBUG=0;
#DRY_RUN
# = 0 means hard run
# > 1 means soft run (no propagation)
our $DRY_RUN=0;

#-------------------------------------------------------------------------
#-----------------------------VARIABLES-----------------------------------
#-------------------------------------------------------------------------

#text predefined constants to use
my $UPN_TEXT = "upn";
my $DELIVERED_TO_MAILBOX_AND_FORWARD_TEXT = "deliverToMailboxAndForward";
my $FORWARDING_SMTP_ADDRESS_TEXT = "forwardingSmtpAddress";
my $ARCHIVE_TEXT = "archive";
my $EMAIL_ADDRESSES_TEXT = "emailaddresses";
my $PLAIN_TEXT_OBJECT_TEXT = "plainTextObject";
my $AD_GROUP_NAME_TEXT = "groupName";
my $SEND_AS_TEXT = "sendAs";
my $COMMAND_TEXT = "command";
my $PARAMETERS_TEXT = "parameters";

#needed global variables and constants for this script
my $instanceName;
my $pathToServiceFile;
my $serviceName;
my $domain = "";
our $successUsers = 0;
our $skippedUsers = 0;
our $failedUsers = 0;
our $successGroups = 0;
our $skippedGroups = 0;
our $failedGroups = 0;
our $returnCode = 0;

#timeouts and constants
our $MAX_WAIT_BATCH=120*60;
our $MAX_WAIT_SEC=180;
our $MAX_WAIT_MSEC = $MAX_WAIT_SEC * 1000;
our $MAX_USERS_CHUNK_SIZE = 500;
our $MAX_GROUPS_CHUNK_SIZE = 50;
our $BASIC_URL;
our $CHECK_URL;
our $USERNAME;
our $PASSWORD;
our $HOST;
our $PORT;
our $TYPE_GET = 'GET';
our $TYPE_PUT = 'PUT';
our $TYPE_POST = 'POST';
our $TYPE_DELETE = 'DELETE';

#-------------------------------------------------------------------------
#--------------------------------CHECKS-----------------------------------
#-------------------------------------------------------------------------

#get options from input of script
GetOptions ("instanceName|i=s" => \$instanceName, "pathToServiceFile|p=s" => \$pathToServiceFile, "serviceName|s=s" => \$serviceName);

checkParameterIsNotNull($instanceName, 'Missing DBNAME to process service.');
checkParameterIsNotNull($pathToServiceFile, 'Missing path to file with generated data to process service.');
checkParameterIsNotNull($serviceName, 'Missing info about service name to process service.');

my $usersDataFilename = "$pathToServiceFile/$serviceName-users";
checkFileExists($usersDataFilename, 'Missing service file with data about users.');
my $groupsDataFilename = "$pathToServiceFile/$serviceName-groups";
checkFileExists($groupsDataFilename, 'Missing service file with data about groups.');
my $facilityIdFilename = "$pathToServiceFile/$serviceName-facilityId";
checkFileExists($facilityIdFilename, 'Missing file with facility id.');

#get and check configuration for communication with o365 server
getConfiguration();

#-------------------------------------------------------------------------
#------------------------------PREPARE DATA-------------------------------
#-------------------------------------------------------------------------

#read facility id from file
my $facilityId = readFacilityId $facilityIdFilename;

#prepare paths to files with cache (users and groups cache)
my $basicCacheDir = "/var/cache/perun/services/$facilityId/$serviceName";
my $cacheDir = $basicCacheDir . "/" . $instanceName . "/";
make_path($cacheDir, { chmod => 0755, error => \my $err });
die "ERROR - Can't create the cache directory $cacheDir.\n" if @$err;
my $lastStateOfUsersFilename = $cacheDir . "o365_mu-users";
my $lastStateOfGroupsFilename = $cacheDir . "o365_mu-groups";

#read data from files and convert them to the hash structure in perl
#read new data about users from PERUN
my $newUsersStruc = readDataAboutUsers $usersDataFilename;

#read new data about groups from PERUN
my $newGroupsStruc = readDataAboutGroups $groupsDataFilename;

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
my $newUsersCache = {};
my $newGroupsCache = {};

#prepare a set of users to process
my $usersToProcessStruc = {};
foreach my $key (keys %$newUsersStruc) {
	my $newUser = $newUsersStruc->{$key};
	my $oldUser = $lastUsersStruc->{$key};

	unless($oldUser) {
		#this is a new user (no record before this one)
		#process him first, add to the cache only if processed sucessfully
		$usersToProcessStruc->{$key} = $newUser;
	} elsif ($newUser->{$PLAIN_TEXT_OBJECT_TEXT} eq $oldUser->{$PLAIN_TEXT_OBJECT_TEXT}) {
		#this is an existing user (record exists) and it is still the same
		#don't process him, only add to the cache
		addObjectToCache($newUsersCache, $key, $newUser);
		$skippedUsers++;
		if($DEBUG>1) { print "~~~ USER: $key\n"; }
	} else {
		#this is an existing user (record exists) and it is different
		#process him first, add to the cache only if processed sucessfully
		$usersToProcessStruc->{$key} = $newUser;
	}
}

#prepare a set of groups to process
my $groupsToProcessStruc = {};
foreach my $key (keys %$newGroupsStruc) {
	my $newGroup = $newGroupsStruc->{$key};
	my $oldGroup = $lastGroupsStruc->{$key};

	unless($oldGroup) {
		#this is a new group (no record before this one)
		#process it first, add to the cache only if processed sucessfully
		$groupsToProcessStruc->{$key} = $newGroup;
	} elsif ($newGroup->{$PLAIN_TEXT_OBJECT_TEXT} eq $oldGroup->{$PLAIN_TEXT_OBJECT_TEXT}) {
		#this is an existing group (record exists) and it is still the same
		#don't process it, only add to the cache
		addObjectToCache($newGroupsCache, $key, $newGroup);
		$skippedGroups++;
		if($DEBUG>1) { print "~~~ GROUP: $key\n"; }
	} else {
		#this is an existing group (record exists) and it is different
		#process it first, add to the cache only if processed sucessfully
		$groupsToProcessStruc->{$key} = $newGroup;
	}
}

#print all prepared informations if DEBUG is in action
if($DEBUG > 1) {
	print "-------------------------------\n";
	print "ALL DATA ABOUT USERS TO PROCESS\n";
	print "-------------------------------\n";
	print Dumper($usersToProcessStruc);
	print "--------------------------------\n";
	print "ALL DATA ABOUT GROUPS TO PROCESS\n";
	print "--------------------------------\n";
	print Dumper($groupsToProcessStruc);
	print "-------------------------------------\n";
	print "ALL DATA ABOUT CACHE USERS TO PROCESS\n";
	print "-------------------------------------\n";
	print Dumper($newUsersCache);
	print "--------------------------------------\n";
	print "ALL DATA ABOUT CACHE GROUPS TO PROCESS\n";
	print "--------------------------------------\n";
	print Dumper($newGroupsCache);
}

#-------------------------------------------------------------------------
#-------------------------------MAIN CODE---------------------------------
#-------------------------------------------------------------------------

my $countOfUsersToProcess = keys %$usersToProcessStruc;
#check all processed users and add them to the cache if they were updated ok
if($countOfUsersToProcess > 0 && $DRY_RUN == 0) {
	#we need to do this in chunks to prevent big queues on the server site
	my @chunksOfUsersStruc = createChunksForStruc( $usersToProcessStruc, $MAX_USERS_CHUNK_SIZE );
	my $chunkCounter = 0;
	foreach my $chunk (@chunksOfUsersStruc) {
		$chunkCounter++;
		if($DEBUG>0) { print "INFO: Users chunk number - $chunkCounter\n"; }
		#users to be updated as content for call
		my $usersContent = getUsersContent($chunk);
		my $usersResult = callServerForUpdate($usersContent) ;
		my $usersResultMap = transformResultToMap($usersResult);
		#check all processed users and add them to the cache if they were updated ok
		foreach my $key (keys %$chunk) {
			my $processedUser = $chunk->{$key};
			my $resultUser = $usersResultMap->{$key};

			#user was processed
			if($resultUser) {
				#check if there was any exception
				my $exception = $resultUser->{'ExceptionMessage'};
				#exception means a problem, return an error, do not add to the cache
				if($exception) {
					my $exceptionType = $resultUser->{'ExceptionType'};
					print STDERR "WARNING - User with ID $key was not processed properly due to: " . $exceptionType . " -- " . $exception . "\n";
					$failedUsers++;
					$returnCode = 1;
				} else {
					#no exception means ok, add to the cache
					addObjectToCache($newUsersCache, $key, $processedUser);
					$successUsers++;
					if($DEBUG>0) { print "+++ USER: $key\n"; }
				}
			} else {
				#if user was not processed at all, it is also an error, do not add to the cache
				print STDERR "WARNING - User with ID $key was timeouted (not processed).\n";
				$failedUsers++;
				$returnCode = 1;
			}
		}
		saveCacheFile( $newUsersCache, $lastStateOfUsersFilename );
	}
}

my $countOfGroupsToProcess = keys %$groupsToProcessStruc;
#check all processed groups and add them to the cache if they were updated ok
if($countOfGroupsToProcess > 0 && $DRY_RUN == 0) {
	#we need to do this in chunks to prevent big queues on the server site
	my @chunksOfGroupsStruc = createChunksForStruc( $groupsToProcessStruc, $MAX_GROUPS_CHUNK_SIZE );
	my $chunkCounter = 0;
	foreach my $chunk (@chunksOfGroupsStruc) {
		$chunkCounter++;
		if($DEBUG>0) { print "INFO: Groups chunk number - $chunkCounter\n"; }

		#groups to be updated as content for call
		my $groupsContent = getGroupsContent($groupsToProcessStruc);
		my $groupsResult = callServerForUpdate($groupsContent);
		my $groupsResultMap = transformResultToMap($groupsResult);
		#check all processed groups and add them to the cache if they were updated ok
		foreach my $key (keys %$chunk) {
			my $processedGroup = $chunk->{$key};
			my $resultGroup = $groupsResultMap->{$key};

			#group was processed
			if($resultGroup) {
				#check if there was any exception
				my $exception = $resultGroup->{'ExceptionMessage'};
				#exception means a problem, return an error, do not add to the cache
				if($exception) {
					my $exceptionType = $resultGroup->{'ExceptionType'};
					print STDERR "WARNING - Group with ID $key was not processed properly due to: " . $exceptionType . " -- " . $exception . "\n";
					$failedGroups++;
					$returnCode = 1;
				} else {
					#no exception means ok, add to the cache
					addObjectToCache($newGroupsCache, $key, $processedGroup);
					$successGroups++;
					if($DEBUG>0) { print "+++ Group: $key\n"; }
				}
			} else {
				#if user was not processed at all, it is also an error, do not add to the cache
				print STDERR "WARNING - Group with ID $key was timeouted (not processed).\n";
				$failedGroups++;
				$returnCode = 1;
			}
		}
		saveCacheFile( $newGroupsCache, $lastStateOfGroupsFilename );
	}
}

#-------------------------------------------------------------------------
#-------------------------------FINALIZING--------------------------------
#-------------------------------------------------------------------------

print "----------------------SUMMARY----------------------\n";
print "-USERS-:\n";
print "~~~ SKIPPED       = $skippedUsers\n";
print "+++ ADDED/UPDATED = $successUsers\n";
print "!!! FAILED        = $failedUsers\n";
print "---------------------------------------------------\n";
print "-GROUPS-:\n";
print "~~~ SKIPPED       = $skippedGroups\n";
print "+++ ADDED/UPDATED = $successGroups\n";
print "!!! FAILED        = $failedGroups\n";
print "---------------------------------------------------\n";

exit $returnCode;

#-------------------------------------------------------------------------
#---------------------------------SUBS------------------------------------
#-------------------------------------------------------------------------

##########################################################################
###Create chunks of the structure.                                     ###
##########################################################################
sub createChunksForStruc {
	my $originalStruc = shift;
	my $chunkSize = shift;

	my @arrayOfStrucs = ();
	my $counter = 0;
	my $struc = {};
	foreach my $key (sort keys %$originalStruc) {
		$struc->{$key} = $originalStruc->{$key};
		$counter++;
		if($counter == $chunkSize) {
			my $newStruc = $struc;
			push @arrayOfStrucs, $newStruc;
			#reset counter and struc
			$struc = {};
			$counter = 0;
		}
	}
	if($counter > 0 && $counter < $chunkSize) {
		push @arrayOfStrucs, $struc;
	}

	return @arrayOfStrucs;
}

##########################################################################
###Add an object to the cache struc.                                   ###
##########################################################################
sub addObjectToCache {
	my $cacheStruc = shift;
	my $key = shift;
	my $object = shift;
	$cacheStruc->{$key} = $object;
}

##########################################################################
###Copy data from cache to the cache file.                             ###
##########################################################################
sub saveCacheFile {
	my $cacheToSave = shift;
	my $destinationFile = shift;

	#create temp file
	my $newCacheFile = new File::Temp( UNLINK => 1 );
	open FILE_CACHE, ">$newCacheFile" or die "ERROR - Could not open file with new cache of users data $newUsersCache: $!\n";

	#save all record to the temp file
	foreach my $key (sort keys %$cacheToSave) {
		print FILE_CACHE $cacheToSave->{$key}->{$PLAIN_TEXT_OBJECT_TEXT} . "\n";
	}

	#close the temp file
	close FILE_CACHE or die "Could not close file $newCacheFile: $!\n";

	#copy temp file to the final cache destination
	copy( $newCacheFile, $destinationFile ) unless $DRY_RUN;
}


##########################################################################
###Check if parameter is not null.                                     ###
###Throw an exception and exit with not null return code if not.       ###
##########################################################################
sub checkParameterIsNotNull {
	my $parameter = shift;
	my $exceptionMessage = shift;

	$exceptionMessage = "Unknown Exception" unless $exceptionMessage;

	if(!defined $parameter) {
		die "ERROR - $exceptionMessage\n";
	}
}

##########################################################################
###Check if there is a existing file on the specific path.             ###
###Throw an exception and exit with not null return code if not.       ###
##########################################################################
sub checkFileExists {
	my $pathToFile = shift;
	my $exceptionMessage = shift;

	$exceptionMessage = "Unknown Exception" unless $exceptionMessage;

	if(! -f $pathToFile) {
		die "ERROR - $exceptionMessage\n";
	}
}


##########################################################################
###Sub to read data about facility id from the file.                   ###
##########################################################################
sub readFacilityId {
	my $pathToFile = shift;

	my $facId;
	open FILE, $pathToFile or die "ERROR - Could not open file with facility id from perun $pathToFile: $!\n";
	while(my $line = <FILE>) {
		chomp( $line );
		unless($facId) {
			$facId = $line;
		} else {
			die "ERROR - There is more than one line in file with facility id $pathToFile!\n";
		}
	}

	unless($facId) {
		die "ERROR - Facility Id can't be obtain from file $pathToFile, it seems to be empty!\n";
	}
	return $facId;
}

##########################################################################
###Sub to read data about users from file and convert it to perl hash. ###
##########################################################################
sub readDataAboutUsers {
	my $pathToFile = shift;

	my $usersStruc = {};
	open FILE, $pathToFile or die "ERROR - Could not open file with users data $pathToFile: $!\n";
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
			print STDERR "WARNING - Can't find UPN for user in $pathToFile for line '$line'\n";
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
	close FILE or die "ERROR - Could not close file $pathToFile: $!\n";

	return $usersStruc;
}

##########################################################################
###Sub to read data about groups from file and convert it to perl hash.###
##########################################################################
sub readDataAboutGroups {
	my $pathToFile = shift;

	my $groupsStruc = {};
	open FILE, $pathToFile or die "ERROR - Could not open file with groups data from perun $pathToFile: $!\n";
	while(my $line = <FILE>) {
		chomp( $line );
		my @parts = split /\t/, $line;
		my $groupADName = $parts[0];
		my @emails = ();
		if($parts[1]) { @emails = split / /, $parts[1]; }

		#If groupADName is from any reason empty, set global return code to 1 and skip this group
		unless($line) {
			print STDERR "WARNING - Can't find AD name of group in $pathToFile for line '$line'\n";
			$returnCode = 1;
			next;
		}

		$groupsStruc->{$groupADName}->{$AD_GROUP_NAME_TEXT} = $groupADName;
		$groupsStruc->{$groupADName}->{$SEND_AS_TEXT} = \@emails;
		$groupsStruc->{$groupADName}->{$PLAIN_TEXT_OBJECT_TEXT} = $line;
	}
	close FILE or die "ERROR - Could not close file $pathToFile: $!\n";

	return $groupsStruc;
}

##########################################################################
###Read configuration from configuration file.                         ###
##########################################################################
sub getConfiguration {
	my $configPath = "/etc/perun/services/$serviceName/$instanceName";
	open FILE, $configPath or die "ERROR - Could not open config file $configPath: $!";
	while(my $line = <FILE>) {
		chomp( $line );
		if($line =~ /^username: .*/) {
			$USERNAME = ($line =~ /^username: (.*)$/)[0];
		} elsif($line =~ /^password: .*/) {
			$PASSWORD = ($line =~ /^password: (.*)$/)[0];
		} elsif($line =~ /^url: .*/) {
			$BASIC_URL = ($line =~ /^url: (.*)$/)[0];
		}
	}

	checkParameterIsNotNull($USERNAME, 'Missing USERNAME to contact o365 server.');
	checkParameterIsNotNull($PASSWORD, 'Missing PASSWORD to contact o365 server.');
	checkParameterIsNotNull($BASIC_URL, 'Missing BASIC URL to contact o365 server.');
}

##########################################################################
###Prepare content from the users to process for the server call.      ###
##########################################################################
sub getUsersContent {
	my $usersToProcess = shift;
	my $command = "Set-MuniMailbox";

	my $content = {};
	$content->{$COMMAND_TEXT} = $command;

	my @parameters = ();
	#prepare users as parameters of the content one by one
	foreach my $key (sort keys %$usersToProcess) {
		my $userToProcess = $usersToProcess->{$key};
		my $user = {};
		$user->{$UPN_TEXT} = $key;
		my $forwardSmtpAddress = $userToProcess->{$FORWARDING_SMTP_ADDRESS_TEXT};
		$user->{$FORWARDING_SMTP_ADDRESS_TEXT} = $forwardSmtpAddress ? $forwardSmtpAddress : JSON::null;
		my $deliverToMailboxAndForward = $userToProcess->{$DELIVERED_TO_MAILBOX_AND_FORWARD_TEXT};
		$user->{$DELIVERED_TO_MAILBOX_AND_FORWARD_TEXT} = $deliverToMailboxAndForward ? JSON::true : JSON::false;
		my $archive = $userToProcess->{$ARCHIVE_TEXT};
		$user->{$ARCHIVE_TEXT} = $archive ? JSON::true : JSON::false;
		my $emailsString = $userToProcess->{$EMAIL_ADDRESSES_TEXT};
		my @emails = ();
		if ($emailsString) {
			@emails = split(",", $emailsString);
		}
		$user->{$EMAIL_ADDRESSES_TEXT} = \@emails;
		push @parameters, $user;
	}

	#add parameters (users) to the content
	$content->{$PARAMETERS_TEXT} = \@parameters;

	return $content;
}

##########################################################################
###Prepare content from the groups to process for the server call.     ###
##########################################################################
sub getGroupsContent {
	my $groupsToProcess = shift;
	my $command = "Set-MuniGroup";

	my $content = {};
	$content->{$COMMAND_TEXT} = $command;

	my @parameters = ();
	foreach my $key (sort keys %$groupsToProcess) {
		my $groupToProcess = $groupsToProcess->{$key};
		my $group = {};
		$group->{$AD_GROUP_NAME_TEXT} = $key;
		$group->{$SEND_AS_TEXT} = $groupToProcess->{$SEND_AS_TEXT};
		push @parameters, $group;
	}

	#add parameters (groups) to the content
	$content->{$PARAMETERS_TEXT} = \@parameters;
	return $content;
}

##########################################################################
###Call server with request and return its response.                   ###
##########################################################################
sub makeRequestToServer {
	my $url = shift;
	my $type = shift;
	my $timeout = shift;
	my $content = shift;

	#encode content to JSON
	my $jsonContent = JSON->new->utf8->encode( $content );

	#prepare all mandatory parts of call
	my $uri = URI->new($url);
        my $host = $uri->host;
        my $port = $uri->port;
	my $address = $host . ":" . $port;
	my $domain = $host;

	#set header
	my $headers = HTTP::Headers->new;
	$headers->header('Content-Type' => 'application/json');
	$headers->header('Accept' => 'application/json,text/json');
	$headers->header('MUNI-WAITTIME' => $timeout );

	#create and call request
	my $ua = LWP::UserAgent->new;
	$ua->timeout($timeout);
	$ua->credentials( $address, $domain, $USERNAME, $PASSWORD );
	my $request = HTTP::Request->new( $type, $url, $headers, $jsonContent );
	my $response = $ua->request($request);
	return $response;
}

##########################################################################
###Call server with data to update all records in the content.         ###
##########################################################################
sub callServerForUpdate {
	my $content = shift;
	my $result = {};

	my $parametersCount = @{$content->{$PARAMETERS_TEXT}};
	my $command = $content->{$COMMAND_TEXT};

	#make first call with data
	my $serverResponse = makeRequestToServer($BASIC_URL . "Set-MuniRequestBatch", $TYPE_POST, $MAX_WAIT_MSEC, $content);
	checkServerResponseStatus($serverResponse);
	my $responseContentJSON = getResponoseContentJSON($serverResponse);
	#url where we can check how many records was already processed
	my $urlToCheckCount = $responseContentJSON->{'responseCountURL'};
	my $urlToGetBatchResult = $responseContentJSON->{'checkBatchURL'};

	my $counter = $MAX_WAIT_BATCH;
	my $processedParametersCount = 0;
	while($counter != 0) {
		#wait a few seconds, then ask for the result
		sleep 5;

		$serverResponse = makeRequestToServer($urlToCheckCount, $TYPE_GET, 100, {});
		checkServerResponseStatus($serverResponse);
		$processedParametersCount = $serverResponse->content();
		print "DEBUG: max:" . $parametersCount . ' vs processed:' . $processedParametersCount . "\n" if $DEBUG>0;

		#if we have all of them, break out of the while and process the result
		last if $parametersCount == $processedParametersCount;

		#if this is not the last one, decrease a counter and try again
		$counter--;
	}

	#0 in $counter means timeout
	unless($counter) {
		print STDERR "WARNING - Batch operation for command '" . $command . "' timeouted. Only '" . $processedParametersCount . "' from '" . $parametersCount . "' were processed before the timeout from Perun site.\n";
		$returnCode = 1;
	}

	#check results, set cache, prepare script output and return code
	$serverResponse = makeRequestToServer($urlToGetBatchResult, $TYPE_GET, 100, {});
	checkServerResponseStatus($serverResponse);
	my $resultContent = getResponoseContentJSON($serverResponse);
	#get all informations from the request
	my $callStatus = $resultContent->{'status'};
	my @psOutput = @{$resultContent->{'psOutput'}};

	#if callStatus is different from Completed,
	$returnCode = 1 if $callStatus ne 'Completed';
	#return all processed objects with info about processing
	return \@psOutput;
}

##########################################################################
###Check if server responose was a success.                            ###
##########################################################################
sub checkServerResponseStatus {
	my $serverResponse = shift;

	unless($serverResponse->is_success) {
		die "ERROR - Communication with PSWS server ended with ERROR:\n" . "STATUS: " . $serverResponse->status_line . "\nCONTENT: " . $serverResponse->decoded_content . "\n";
	}
}

##########################################################################
###Parse content from server response and decode it to the JSON format.###
##########################################################################
sub getResponoseContentJSON {
	my $serverResponse = shift;

	my $responseContent = $serverResponse->content();
	$responseContent =~ s/^"//;
	$responseContent =~ s/"$//;

	my  $responseJSON = JSON->new->utf8->decode( $responseContent );

	return $responseJSON;
}

##########################################################################
###Transform server results of objects to map for better processing.   ###
##########################################################################
sub transformResultToMap {
	my $resultArray = shift;
	my $resultMap = {};
	foreach my $result (@$resultArray) {
		my $objectId = $result->{'ObjectID'};
		#if object ID is not in the first attribute, try to find second one
		$objectId = $result->{'ProcessedObjectID'} unless $objectId;
		#if no objectId was found, we have a major problem in processing results
		die "ERROR - Missing object ID for processed object\n" . Dumper($result) unless $objectId;
		$resultMap->{$objectId} = $result;
	}

	return $resultMap;
}
