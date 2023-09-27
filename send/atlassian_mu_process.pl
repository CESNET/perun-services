#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long qw(:config no_ignore_case);
use LWP::UserAgent;
use JSON::XS;
use HTTP::Request;
use HTTP::Headers;
use Data::Dumper;
use Array::Utils qw(:all);

### Example command - requires import directory and configuration filepath.
=c
./atlassian_mu_process.pl -d ../gen/spool/facilityName/atlassian_mu/ -c /etc/perun/services/atlassian_mu/destination
=cut
#-----------------------------CONSTANTS------------------------------------
# (0) no debug, (1) only messages of performed operations, (2) communication with server.
my $DEBUG=0;

my $DEACTIVATED_PREFIX_INIT=0;

# Required setting for connection
my $RESULTS_COUNT = 200; # This many objects will be fetched with one GET request on server. Limited by Atlassian ANYWAY!
my $directoryUrl;
my $key;

# Passed parameters
my $configFile;
my $importDirectory;

# Other constants
my $TYPE_GET = 'GET';
my $TYPE_PUT = 'PUT';
my $TYPE_POST = 'POST';
my $TYPE_PATCH = 'PATCH';
my $TYPE_DELETE = 'DELETE';
my @ATLASSIAN_ERROR_CODES = (500, 503); # Internal Atlassian error codes
my $WAITING_ERROR_TIME = 20 * 1000; # Wait this long (ms) if above error occurs
my $REPEAT_ERROR_COUNT = 3; # Retry this many times if above error occurs
my $GROUP_OPERATIONS_LIMIT = 9999; # Limit of group operations in a chunk on Atlassian side

my $USERS_FILENAME = 'users.scim';
my $GROUPS_FILENAME = 'groups.scim';

# Statistics
my $groupsCreated = 0;
my $groupsRemoved = 0;
my $membershipUpdated = 0;
my $usersCreated = 0;
my $usersUpdated = 0;
my $usersDeactivated = 0;

#--------------------------------------------------------------------------

# Method with information about possible parameters of this script
sub help {
	return qq{
Fetches users and groups from Atlassian via REST API, compares differences and updates objects in Atlassian using SCIM.
Return help + exit 1 if help is needed.
Return STDOUT + exit 0 if everything is ok.
Return STDERR + exit >0 if error happens.
---------------------------------------------------------
Other options:
 --help                | -h prints this help
Mandatory parameters:
 --configFile          | -c configuration file with key and base directory URL
 --importDirectory     | -d directory with data files\n
};
}

# Get options from input of script
GetOptions("help|h"	=> sub {
	print help;
	exit 1;
},
	"configFile|c=s" => \$configFile,
	"importDirectory|d=s" => \$importDirectory) || die help;

unless ($configFile) {die "Configuration file (-c) is required!\n"}
unless ($importDirectory) {die "Import directory (-d) is required!\n"}

# -------------------------------------------------------------------------------------------

# Check configuration file exists and contains required properties
open FILE, $configFile or die "Could not open config file $configFile: $!\n";
while(my $line = <FILE>) {
	if ($line =~ /^key: .*/) {
		$key = ($line =~ m/^key: (.*)$/)[0];
	}
	elsif ($line =~ /^url: .*/) {
		$directoryUrl = ($line =~ m/^url: (.*)$/)[0];
	}
}
close FILE or die "Could not close configuration file $configFile: $!\n";
unless ($key) {die "API key is missing in configuration file!\n"}
unless ($directoryUrl) {die "Base directory URL is missing in configuration file!\n"}

# Data from perun into hash
my $ourUsers = fetchOurUsers();
my $ourGroups = fetchOurGroups();
# Data from Atlassian into hash
my $theirUsers = fetchTheirUsers();

if ($DEACTIVATED_PREFIX_INIT) {
	addPrefixToDeactivatedUsers();
}
evaluateUsers();
my $theirGroups = fetchTheirGroups(); # Acquire groups now to account for updated usernames with prefixes
$theirUsers = fetchTheirUsers(); # Acquire created users' IDs
evaluateGroups();

# Print statistics message and end with 0 if everything goes well
printStats();
exit 0;

# -------------------------------------------------------------------------------------------

# This method calls specific url with predefined content in json.
# Returns decoded json response or dies with error.
# Retries after specified time if error is on Atlassian's side.
sub callServer {
	my $url = shift;
	my $type = shift;
	my $content = shift;

	my $serverResponse = createConnection( $url, $type, $content );
	my $repeatCounter = 0;
	while (checkAtlassianError($serverResponse) && $repeatCounter < $REPEAT_ERROR_COUNT) {
		sleep($WAITING_ERROR_TIME);
		$serverResponse = createConnection( $url, $type, $content );
		$repeatCounter++;
	}
	my $serverResponseJson = checkServerResponse( $serverResponse );

	return $serverResponseJson;
}

# This method just takes all parameters and creates connection to the server.
# Then returns it's response.
sub createConnection {
	my $url = shift;
	my $type = shift;
	my $content = shift;

	my $headers = HTTP::Headers->new;
	$headers->header('Content-Type' => 'application/json');
	$headers->header('Accept' => 'application/json');
	$headers->header('Authorization' => "Bearer $key");

	my $ua = LWP::UserAgent->new;
	my $request = HTTP::Request->new( $type, $url, $headers, $content );
	if ($DEBUG == 2) {print "REQUEST IS: " . Dumper $request};
	return $ua->request($request);
}

# This method checks if response of server was success.
# If yes, return decoded json response, if not, die with error.
sub checkServerResponse {
	my $response = shift;
	my $responseJson;

	if ($DEBUG == 2) {print "SERVER RESPONSE IS: " . Dumper $response};
	if ($response->is_success) {
		if ($response->content) {
			$responseJson = JSON::XS->new->utf8->decode($response->content);
		}
	} else {
		die $response->status_line . "\n" . $response->decoded_content . "\n";
	}

	return $responseJson;
}

# Checks if response contains server error worth retrying the call for.
# These are specified in ATLASSIAN_ERROR_CODES list.
# Returns (1) if response code is Atlassian error, (0) otherwise.
sub checkAtlassianError {
	my $response = shift;
	my $responseStatus = int($response->code);
	foreach my $errorCode (@ATLASSIAN_ERROR_CODES) {
		if ($errorCode == $responseStatus) {
			return 1;
		}
	}
	return 0;
}

# Fetches users from Atlassian. Selects only necessary information and stores in users hash.
# Requires pagination, number of items per page is set in RESULTS_COUNT variable.
sub fetchTheirUsers {
	my $startIndex = 1;
	my $itemsPerPage = 0;
	my $totalResults = 2;
	if ($DEBUG) {print "Fetching users from Atlassian...\n";}

	my %theirUsersHash = ();

	while ($startIndex <= $totalResults) {
		my $url = $directoryUrl . '/Users?startIndex=' . $startIndex . '&count=' . $RESULTS_COUNT;
		my $response = callServer($url, $TYPE_GET);
		$totalResults = $response->{'totalResults'};
		$itemsPerPage = $response->{'itemsPerPage'};
		$startIndex = $response->{'startIndex'} + $itemsPerPage;

		foreach my $theirUser (@{$response->{'Resources'}}) {
			resolveUser($theirUser, \%theirUsersHash);
		}
	}
	if ($DEBUG) {my $size = keys %theirUsersHash; print "Fetched $size users of total count $totalResults.\n";}
	return \%theirUsersHash;
}

# Fetches groups from Atlassian. Selects only necessary information and stores in groups hash.
# Requires pagination, number of items per page is set in RESULTS_COUNT variable.
sub fetchTheirGroups {
	my $startIndex = 1;
	my $itemsPerPage = 0;
	my $totalResults = 2;
	if ($DEBUG) {print "Fetching groups from Atlassian...\n";}

	my %theirGroupsHash = ();

	while ($startIndex <= $totalResults) {
		my $url = $directoryUrl . '/Groups?startIndex=' . $startIndex . '&count=' . $RESULTS_COUNT;
		my $response = callServer($url, $TYPE_GET);
		$totalResults = $response->{'totalResults'};
		$itemsPerPage = $response->{'itemsPerPage'};
		$startIndex = $response->{'startIndex'} + $itemsPerPage;

		foreach my $theirGroup(@{$response->{'Resources'}}) {
			resolveGroup($theirGroup, \%theirGroupsHash);
		}
	}

	if ($DEBUG) {my $size = keys %theirGroupsHash; print "Fetched $size groups of total count $totalResults.\n";}
	return \%theirGroupsHash;
}

# Parse user from fetched data to necessary information and add it to obtained hash.
sub resolveUser {
	my $theirUser = shift;
	my $theirUsersHashRef = shift;

	my $userInfo = {};
	$userInfo->{"email"} = $theirUser->{'emails'}[0]->{'value'};
	$userInfo->{"givenName"} = $theirUser->{'name'}->{'givenName'};
	$userInfo->{"familyName"} = $theirUser->{'name'}->{'familyName'};
	$userInfo->{"id"} = $theirUser->{'id'};
	$userInfo->{"active"} = $theirUser->{'active'};

	$theirUsersHashRef->{$theirUser->{'userName'}} = $userInfo;
}

# Parse group from fetched data to necessary information and add it to obtained hash.
sub resolveGroup {
	my $theirGroup = shift;
	my $theirGroupsHashRef = shift;

	my @groupMembers = ();
	foreach my $member (@{$theirGroup->{'members'}}) {
		push @groupMembers, $member->{'display'};
	}

	my %groupInfo;
	$groupInfo{"members"} = \@groupMembers;
	$groupInfo{"id"} = $theirGroup->{'id'};
	$theirGroupsHashRef->{$theirGroup->{'displayName'}} = \%groupInfo;
}

#Fetch users from Perun.
sub fetchOurUsers {
	my $json_users = do {
		open(my $json_fh, "<:encoding(UTF-8)", $importDirectory . $USERS_FILENAME)
			or die("Can't open " . $importDirectory . $USERS_FILENAME . ": $!\n");
		local $/;
		<$json_fh>
	};

	return JSON::XS->new->decode($json_users);
}

# Fetch groups from Perun.
sub fetchOurGroups {
	my $json_groups = do {
		open(my $json_fh, "<:encoding(UTF-8)", $importDirectory . $GROUPS_FILENAME)
			or die("Can't open " . $importDirectory . $GROUPS_FILENAME . ": $!\n");
		local $/;
		<$json_fh>
	};

	return JSON::XS->new->decode($json_groups);
}

# temporary function to update atlassian with the new feature of prefixes for deactivated users
sub addPrefixToDeactivatedUsers {
	print("Updating usernames of deactivated users to contain the 'del' prefix. \n");
	my $theirUserName;
	my $theirUserInfo;
	while (($theirUserName, $theirUserInfo) = each(%{$theirUsers})) {
		my $prefix = substr $theirUserName, 0, 4;
		if (!$theirUserInfo->{'active'} && $prefix ne "del_") {
			$theirUserInfo->{"email"} = 'del_'.$theirUserInfo->{"email"};
			updateUser('del_'.$theirUserName, $theirUserInfo, $theirUserInfo->{'id'}, 0);
		}
	}
	print("Done updating usernames. \n");
}

# Compares Atlassian users with Perun users.
# Sends request to create missing users, update outdated user data and deactivate users missing in Perun.
sub evaluateUsers {
	my $theirUserName;
	my $theirUserInfo;
	while (($theirUserName, $theirUserInfo) = each(%{$theirUsers})) {
		# remove potential del_ prefix to correctly match with our users
		$theirUserName =~ s/^del_//;
		my $ourUserInfo = $ourUsers->{$theirUserName};
		if (!$ourUserInfo && $theirUserInfo->{'active'}) {
			# add del_ prefix since we're deactivating user
			$theirUserInfo->{"email"} = 'del_'.$theirUserInfo->{"email"};
			updateUser('del_'.$theirUserName, $theirUserInfo, $theirUserInfo->{'id'}, 0);
		}
	}

	my $ourUserName;
	my $ourUserInfo;
	while (($ourUserName, $ourUserInfo) = each(%{$ourUsers})) {
		$theirUserInfo = $theirUsers->{$ourUserName};
		# check if user isn't marked as deleted
		if (!defined $theirUserInfo) {
			$theirUserInfo = $theirUsers->{'del_'.$ourUserName};
		}
		if (defined $theirUserInfo) {
			# check if attributes changed or our user got active again
			if (checkUserAttributesDiffer($ourUserInfo, $theirUserInfo) || !$theirUserInfo->{"active"}) {
				updateUser($ourUserName, $ourUserInfo, $theirUserInfo->{'id'}, 1);
			}
		} else {
			createUser($ourUserName, $ourUserInfo);
		}
	}
}

# Compares Atlassian groups with Perun groups.
# Sends request to create missing groups, remove outdated groups and resolve group memberships.
sub evaluateGroups {
	my $ourGroupName;
	my $ourGroupMembers;
	while (($ourGroupName, $ourGroupMembers) = each(%{$ourGroups})) {

		my @exclusivelyOurMembers;
		my @exclusivelyTheirMembers;

		my $groupId;
		unless (exists $theirGroups->{$ourGroupName}) {
			#id comes with server response on create call
			$groupId = createGroup($ourGroupName)->{'id'};
			@exclusivelyOurMembers = @$ourGroupMembers;
			@exclusivelyTheirMembers = ();
		} else {
			# we must check group exists first, otherwise this would create record in the hash with our group name
			my $theirGroupMembers = $theirGroups->{$ourGroupName}->{"members"};
			@exclusivelyOurMembers = array_minus(@$ourGroupMembers, @$theirGroupMembers);
			@exclusivelyTheirMembers = array_minus(@$theirGroupMembers, @$ourGroupMembers);
			$groupId = $theirGroups->{$ourGroupName}->{'id'};
		}

		updateGroupMembership($groupId, \@exclusivelyOurMembers, \@exclusivelyTheirMembers);
	}

	my $theirGroupName;
	my $theirGroupInfo;
	while (($theirGroupName, $theirGroupInfo) = each(%{$theirGroups})) {
		unless (exists $ourGroups->{$theirGroupName}) {
			removeGroup($theirGroupInfo->{'id'})
		}
	}
}

# Sends request to create a group in Atlassian.
sub createGroup {
	my $displayName = shift;
	if ($DEBUG) {print "Creating group $displayName.\n";}

	my $data = { "displayName" => $displayName };
	$groupsCreated++;
	return callServer($directoryUrl . '/Groups', $TYPE_POST, JSON::XS->new->utf8->encode($data));
}

# Sends request to remove a group from Atlassian.
sub removeGroup {
	my $groupId = shift;
	if ($DEBUG) {print "Removing group $groupId.\n";}

	callServer($directoryUrl . '/Groups/' . $groupId, $TYPE_DELETE);
	$groupsRemoved++;
}

# Compares members of group from Atlassian with members of group in Perun.
# Sends request to update membership if members are missing or are outdated.
sub updateGroupMembership {
	my $groupId = shift;
	my $exclusivelyOurMembers = shift;
	my $exclusivelyTheirMembers = shift;
	my $newMembersCount = scalar @$exclusivelyOurMembers;
	my $outdatedMembersCount = scalar @$exclusivelyTheirMembers;

	unless ($newMembersCount || $outdatedMembersCount) {
		if ($DEBUG) {print "Group membership for group with id $groupId is up to date.\n";}
		return;
	}

	if ($DEBUG) {print "Updating group membership for group with id $groupId. $newMembersCount members to be added, $outdatedMembersCount to be removed.\n";}

	my @membersToAdd = ();
	for my $newMember (@$exclusivelyOurMembers) {
		unless (exists $theirUsers->{$newMember}) { die "Data not properly fetched, $newMember missing in server data.\n"; }
		push @membersToAdd, {"value" => $theirUsers->{$newMember}->{"id"}, "display" => $newMember};
	}
	my @membersToRemove = ();
	for my $outdatedMember (@$exclusivelyTheirMembers) {
		push @membersToRemove, {"value" => $theirUsers->{$outdatedMember}->{"id"}, "display" => $outdatedMember};
	}

	# Chunks need to be used for membership operations because of operations limit in Atlassian
	my @chunks_to_remove = ();
	push @chunks_to_remove, [ splice @membersToRemove, 0, $GROUP_OPERATIONS_LIMIT ] while @membersToRemove;
	foreach (@chunks_to_remove) {
		my $updateContent = {
			"schemas"    => [ "urn:ietf:params:scim:api:messages:2.0:PatchOp" ],
			"Operations" => [
				{ "op"      => "remove",
					"path"  => "members",
					"value" => \@$_}
			]
		};

		callServer($directoryUrl . '/Groups/' . $groupId, $TYPE_PATCH, JSON::XS->new->utf8->encode($updateContent));
	}

	my @chunks_to_add = ();
	push @chunks_to_add, [ splice @membersToAdd, 0, $GROUP_OPERATIONS_LIMIT ] while @membersToAdd;
	foreach (@chunks_to_add) {
		my $updateContent = {
			"schemas"    => [ "urn:ietf:params:scim:api:messages:2.0:PatchOp" ],
			"Operations" => [
				{"op" => "add",
					"path" => "members",
					"value" => \@$_}
			]
		};

		callServer($directoryUrl . '/Groups/' . $groupId, $TYPE_PATCH, JSON::XS->new->utf8->encode($updateContent));
	}

	$membershipUpdated++;
}

# Send request to update user.
# Can be used to deactivate user.
sub updateUser {
	my $userName = shift;
	my $userInfo = shift;
	my $userId = shift;
	my $statusActive = shift;
	my $nameWithoutPrefix = substr $userName, 4;
	if ($DEBUG) {print $statusActive ? "Updating user $userName.\n" : "Deactivating user $nameWithoutPrefix.\n" ;}

	my $updateContent = {
		"userName" => $userName,
		"emails"   => [{ "value"	 => $userInfo->{"email"},
						 "type"		 => "work",
						 "primary"	 => JSON::XS::true }],
		"name"     => { "givenName"  => $userInfo->{"givenName"},
						"familyName" => $userInfo->{"familyName"}},
		"active"   => $statusActive ? JSON::XS::true : JSON::XS::false
	};

	callServer($directoryUrl . '/Users/' . $userId, $TYPE_PUT, JSON::XS->new->utf8->encode($updateContent));
	if ($statusActive) { $usersUpdated++ } else { $usersDeactivated++ };
}

# Send request to create user with given username and info.
sub createUser {
	my $ourUserName = shift;
	my $ourUserInfo = shift;
	if ($DEBUG) { print "Create user $ourUserName \n"; }

	my $data = {
		"userName" => $ourUserName,
		"emails"   => [{ "value"	 => $ourUserInfo->{"email"},
						"type"		 => "work",
						"primary"	 => JSON::XS::true }],
		"name"     => { "givenName"  => $ourUserInfo->{"givenName"},
						"familyName" => $ourUserInfo->{"familyName"}},
		"active"   => JSON::XS::true
	};

	callServer($directoryUrl . '/Users', $TYPE_POST, JSON::XS->new->utf8->encode($data));
	$usersCreated++;
}

# Checks if information about user from Atlassian are up to date with Perun data.
# Returns (1) if information differs, (0) if no update.
sub checkUserAttributesDiffer {
	my $ourUserInfo = shift;
	my $theirUserInfo = shift;

	if ($ourUserInfo->{"givenName"} ne $theirUserInfo->{"givenName"} ||
		$ourUserInfo->{"familyName"} ne $theirUserInfo->{"familyName"} ||
		$ourUserInfo->{"email"} ne $theirUserInfo->{"email"}) {
		return 1;
	}
	return 0;
}

# Prints info about how many objects were created/updated/removed.
sub printStats {
	print "Created " . $groupsCreated . " new groups.\n";
	print "Removed " . $groupsRemoved . " outdated groups.\n";
	print "Updated memberships in " . $membershipUpdated . " groups" . ($groupsCreated ? " (including created groups)" : "") . ".\n";
	print "Created " . $usersCreated . " new users.\n";
	print "Updated or reactivated " . $usersUpdated . " users.\n";
	print "Deactivated " . $usersDeactivated . " users.\n";
}
