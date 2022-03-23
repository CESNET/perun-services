#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long qw(:config no_ignore_case);
use LWP::UserAgent;
use JSON;
use HTTP::Request;
use HTTP::Headers;
use Data::Dumper;

### Example command - contains import token (t) and directory (d) with json objects to be imported.
### All files in the directory will be imported to Jira Insight in a bulk.
### If something fails, import is unfinished and is canceled with next calling of this script.
=c
./insight-connector.pl -d ../gen/spool/insight_mu -t {token}
=cut
#-----------------------------CONSTANTS------------------------------------
# DEBUG can be turned on (1) or off (0)
my $DEBUG=0;

# Required setting for connection
my $INFO_URL = 'https://api.atlassian.com/jsm/insight/v1/imports/info';
my $GET_STATUS_URL;
my $START_URL;
my $SUBMIT_RESULTS_URL;
my $GET_EXECUTION_STATUS;

# Passed parameters
my $token;
my $importDirectory;

# Other constants
my $TYPE_GET = 'GET';
my $TYPE_POST = 'POST';
my $TYPE_DELETE = 'DELETE';
my $STATUS_IDLE = 'IDLE';
my $STATUS_RUNNING = 'RUNNING';
# When finalChunk is sent to SUBMIT RESULTS endpoint, the import is finished
my $finalChunk = '{"completed": true}';
# How many times (+4s waiting) should the execution status be waited for to finish
my $maxwait = 6;
#--------------------------------------------------------------------------

# Method with information about possible parameters of this script
sub help {
	return qq{
Import all files (json) from import directory to Jira INSIGHT via REST API.
Return help + exit 1 if help is needed.
Return STDOUT + exit 0 if everything is ok.
Return STDERR + exit >0 if error happens.
---------------------------------------------------------
Other options:
 --help                | -h prints this help
Mandatory parameters:
 --token               | -t import token
 --importDirectory     | -d command to call\n
};
}

# Get options from input of script
GetOptions("help|h"	=> sub {
	print help;
	exit 1;
},
	"token|t=s" => \$token,
	"importDirectory|d=s" => \$importDirectory) || die help;

if (!$token) {die "Token (-t) is required!\n"}
if (!$importDirectory) {die "Import directory (-d) is required!\n"}

# Call INFO endpoint with token to obtain endpoints
my $info_links = callServer($INFO_URL, $TYPE_GET);
if (!$info_links->{'links'}) {die "Missing data in server response!\n"}
$START_URL = $info_links->{'links'}->{'start'};
$GET_STATUS_URL = $info_links->{'links'}->{'getStatus'};

# Start import
checkImportReady();
my $import_links = callServer($START_URL, $TYPE_POST);
if (!$import_links->{'links'}) {die "Missing data in server response!\n"}
$SUBMIT_RESULTS_URL = $import_links->{'links'}->{'submitResults'};
$GET_EXECUTION_STATUS = $import_links->{'links'}->{'getExecutionStatus'};
importFilesFromDirectory();

# Finish import
callServer($SUBMIT_RESULTS_URL, $TYPE_POST, $finalChunk);

my $jsonResult;
my $counter = 0;
while ((!$jsonResult || !$jsonResult->{'status'} || $jsonResult->{'status'} ne "DONE") && $counter < $maxwait) {
	if ($counter >= $maxwait) { die "Timeout for execution status, did not receive import status!\n" }
	sleep 4;
	$jsonResult = callServer($GET_EXECUTION_STATUS, $TYPE_GET);
	$counter++;
}

# Print results for each entity type
if ($jsonResult) {
	my $results = $jsonResult->{'progressResult'}->{'objectTypeResultMap'};
	for my $object (keys %$results) {
		my $updatedEntries = $results->{$object}->{'objectsUpdated'};
		my $createdEntries = $results->{$object}->{'objectsCreated'};
		my $sentEntries = $results->{$object}->{'entriesInSource'};
		print $results->{$object}->{'objectTypeName'} . " entries"
			. ": sent " . $sentEntries
			. ", created " . $createdEntries
			. ", updated " . $updatedEntries . "\n";
		if ($sentEntries != $updatedEntries + $createdEntries) {
			print "   Some entries were ignored!\n"
		}
		if ($results->{$object}->{'errorMessages'}) {
			print "   Error message: " . $results->{$object}->{'errorMessages'} . "\n";
		}
	}
} else {
	die "Did not receive import status!\n"
}

#End with 0 if everything goes well
exit 0;


#Name:
# callServer
#-----------------------
#Parameters:
# url     - url of server and method address to call
# type    - GET, POST or DELETE
# content - hash content of request, will be encoded to json output
#-----------------------
#Returns:
# server response as json
# die in other case (error)
#-----------------------
#Description:
# This method calls specific url with predefined content in json.
# And returns decoded json response or dies with error.
#-----------------------
sub callServer {
	my $url = shift;
	my $type = shift;
	my $content = shift;

	my $serverResponse = createConnection( $url, $type, $content );
	my $serverResponseJson = checkServerResponse( $serverResponse );

	return $serverResponseJson;
}

#Name:
# createConnection
#-----------------------
#Parameters:
# url     - url of server to call
# type    - GET, POST or DELETE
# content - json with data
#-----------------------
#Returns: Response of server on our request.
#-----------------------
#Description:
# This method just takes all parameters and creates connection to the server.
# Then returns it's response.
#-----------------------
sub createConnection {
	my $url = shift;
	my $type = shift;
	my $content = shift;

	my $headers = HTTP::Headers->new;
	$headers->header('Content-Type' => 'application/json');
	$headers->header('Accept' => 'application/json');
	$headers->header('Authorization' => "Bearer $token");

	my $ua = LWP::UserAgent->new;
	my $request = HTTP::Request->new( $type, $url, $headers, $content );
	if ($DEBUG) {print "REQUEST IS: " . Dumper $request};
	return $ua->request($request);
}

#Name:
# checkServerResponse
#-----------------------
#Parameters:
# response - response from server in JSON format
#-----------------------
#Returns: decoded json respons if response is success, die if response of server is not success
#-----------------------
#Description:
# This method checks if response of server was success. If yes, return decoded json response,
# if not, die with error.
#-----------------------
sub checkServerResponse {
	my $response = shift;
	my $responseJson;

	if ($response->is_success) {
		if ($response->content) {
			if ($DEBUG) {print "SERVER RESPONSE IS: " . Dumper $response};
			$responseJson = JSON->new->utf8->decode($response->content);
		}
	} else {
		die $response->status_line . "\n";
	}

	return $responseJson;
}

#Name:
# checkImportReady
#-----------------------
#Description:
# Checks if server is ready (IDLE) for importing new data.
# If RUNNING, previous import was not finished - then cancel that import first.
# Otherwise die.
#-----------------------
sub checkImportReady {
	my $responseJson = callServer($GET_STATUS_URL, $TYPE_GET);
	if ($responseJson->{'status'} ne $STATUS_IDLE) {
		if ($responseJson->{'status'} eq $STATUS_RUNNING) {
			if ($DEBUG) {print "Cancelling previous unfinished import.\n"}
			callServer($responseJson->{'links'}->{'cancel'}, $TYPE_DELETE);
		} else {
			die "Status endpoint needs to be IDLE, got: " . $responseJson->{'status'} . "\n";
		}
	}
}

#Name:
# importFilesFromDirectory
#-----------------------
#Description:
# Reads content of EVERY file in import directory and calls SUBMIT RESULTS endpoint for each file.
# Import needs to be finished after by sending final data chunk.
# Dies if error occurs.
#-----------------------
sub importFilesFromDirectory {
	# if directory ends with slash, remove it
	$importDirectory =~ s/\/$//;
	opendir(DIR, $importDirectory) or die "Could not open $importDirectory: $!\n";

	my $filename;
	while ($filename = readdir(DIR)) {
		# skip '.' and '..' directories
		next if ($filename =~ /^\.+$/);
		my $filepath = "$importDirectory/$filename";
		if ($DEBUG) {print "Importing file: $filepath\n"}
		open my $fh, '<', $filepath or die "Error opening $filepath: $!\n";
		my $data = do { local $/; <$fh> };
		callServer($SUBMIT_RESULTS_URL, $TYPE_POST, $data);
	}

	closedir(DIR);
}
