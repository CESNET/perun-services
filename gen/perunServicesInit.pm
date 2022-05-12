#!/usr/bin/perl
package perunServicesInit;

use Exporter 'import';
@EXPORT_OK = qw(init);
@EXPORT= qw(getDirectory getDestinationDirectory getHierarchicalData getDataWithGroups getDataWithVos getHashedDataWithGroups getHashedHierarchicalData);

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);
use Perun::Agent;
use File::Path;
use File::Temp qw/ tempdir /;
use File::Temp qw/ :mktemp  /;
use File::Copy;
use Data::Dumper;
use IO::Compress::Gzip qw(gzip $GzipError) ;
use Storable;

# variables define possible getData methods what can be execute
our $DATA_TYPE_HIERARCHICAL="hierarchical";
our $DATA_TYPE_HASHED_HIERARCHICAL="hashedhierarchical";
our $DATA_TYPE_FLAT="flat";
our $DATA_TYPE_HASHED_WITH_GROUPS="hashedwithgroups";
our $DATA_TYPE_WITH_GROUPS="withgroups";
our $DATA_TYPE_WITH_VOS="withvos";
our $DATA_TYPE = {
	$DATA_TYPE_HASHED_HIERARCHICAL => sub {getHashedHierarchicalData(@_)},
	$DATA_TYPE_HIERARCHICAL => sub {getHierarchicalData(@_)},
	$DATA_TYPE_FLAT => sub {getFlatData(@_)},
	$DATA_TYPE_HASHED_WITH_GROUPS => sub {getHashedDataWithGroups(@_)},
	$DATA_TYPE_WITH_GROUPS => sub {getDataWithGroups(@_)},
	$DATA_TYPE_WITH_VOS => sub {getDataWithVos(@_)},
};

#die at the very end of script when any warning occur during executing
our $DIE_AT_END=0;
$SIG{__WARN__} = sub { $DIE_AT_END=1; warn @_; };
END { if($DIE_AT_END) { die "Died because of warning(s) occur during processing.\n"; } };

my ($agent, $service, $facility, $servicesAgent, $directory, $tmp_directory, $tmp_directory_destination, $getData_directory, $local_data);

# Parameter that enforces consent evaluation
our $CONSENT_EVAL = 0;

# Prepare directory for file which will be generated
# Create VERSION file in this directory. This file contains protocol version
#
# This method REQUIRE access to $::SERVICE_NAME and $::PROTOCOL_VERSION
# this can be achieved by following lines in your main script: (for example)
#     local $::SERVICE_NAME = "passwd";
#     local $::PROTOCOL_VERSION = "3.0.0";
sub init {

	my ($facilityId, $facilityName, $local_data_file, $serviceName, $getDataType);
	GetOptions ("consentEval|c"=>\$CONSENT_EVAL,"facilityId|f=i" => \$facilityId, "facilityName|F=s" => \$facilityName, "data|d=s" => \$local_data_file, "serviceName|s=s" => \$serviceName, "getDataType|t=s" => \$getDataType) or die;
	# serviceName is way how to specify service from argument, use it instead local SERVICE_NAME if set
	if(defined $serviceName) { $::SERVICE_NAME = $serviceName; }

	unless(defined $::SERVICE_NAME) { die; }
	unless(defined $::PROTOCOL_VERSION) {die;}

	# some services support variable getData method type, default is hierarchical
	# if service does not support this variable behavior, then it does not care about this setting
	if(!defined($getDataType)) { $getDataType = "hierarchical"; }
	if(defined($DATA_TYPE->{$getDataType})) {
		$::GET_DATA_METHOD = $DATA_TYPE->{$getDataType};
	} else {
		die "Not supported getData type $getDataType! Use one of these: '$DATA_TYPE_HIERARCHICAL', '$DATA_TYPE_HASHED_HIERARCHICAL', '$DATA_TYPE_FLAT', '$DATA_TYPE_WITH_GROUPS', '$DATA_TYPE_HASHED_WITH_GROUPS' or '$DATA_TYPE_WITH_VOS'.";
	}

	if(defined $local_data_file) {
		die "ERROR facilityName required" unless defined $facilityName;
		die "ERROR: Cannot read $local_data_file: $! " unless -r $local_data_file;

		$local_data = retrieve $local_data_file;

	} else {
		unless(defined $facilityId) { die "ERROR: facilityId required"; }

		my $jsonFormat = $::JSON_FORMAT || "jsonsimple";
		unless($jsonFormat =~ /^json(simple)?$/) {
			die 'Unsupported json format. Set $::JSON_FORMAT to any of supported formats. Only "json" and "jsonsimple" are supported.';
		}

 		$agent = Perun::Agent->new($jsonFormat);
		$servicesAgent = $agent->getServicesAgent;
		my $facilitiesAgent = $agent->getFacilitiesAgent;
		$service = $servicesAgent->getServiceByName( name => $::SERVICE_NAME);
		$facility = $facilitiesAgent->getFacilityById( id => $facilityId);
		$facilityName = $facility->getName;
	}

	$directory = "spool/" . $facilityName . "/" . $::SERVICE_NAME."/";
	$tmp_directory = "spool/tmp/" . $facilityName . "/" . $::SERVICE_NAME."/";
	$tmp_directory_destination = $tmp_directory . "/_destination/";
	$getData_directory = "spool/tmp/getData/" . $facilityName . "/" . $::SERVICE_NAME."/";

	my $err;
	rmtree($tmp_directory,  { error => \$err } );
	if(@$err) { die "Can't rmtree( $tmp_directory  )" };
	mkpath($tmp_directory, { error => \$err } );
	if(@$err) { die "Can't mkpath( $tmp_directory  )" };
	mkpath($tmp_directory_destination, { error => \$err } );
	if(@$err) { die "Can't mkpath( $tmp_directory_destination  )" };
	createVersionFile();
	createServicesFile();
	createFacilityNameFile($facilityName);

	rmtree($getData_directory);
	if(@$err) { die "Can't rmtree( $getData_directory  )" };
	mkpath($getData_directory);
	if(@$err) { die "Can't mkpath( $getData_directory  )" };
}

sub finalize {
	unless($DIE_AT_END) {
		my $err;
		rmtree($directory, { error => \$err } );
		if(@$err) { die "Can't rmtree( $directory  )" };

		mkpath($directory, { error => \$err } );
		if(@$err) { die "Can't mkpath( $directory  )" };

		move("$tmp_directory", "$directory") or die "Cannot move $tmp_directory to $directory dir: ", $!;
	}
}

#Commented because of big amount of data in memory (usage)
sub logData {
	#my $data = shift || die "No data";
	#my $file = shift || "data";
	#my $dataFile = new IO::Compress::Gzip "$getData_directory/$file.gz" or die "IO::Compress::Gzip failed: $GzipError\n";
	#print $dataFile Dumper($data);
}

sub getAgent {
	return $agent;
}

sub getFacility {
	return $facility;
}

sub getHashedHierarchicalData {
	if(defined $local_data) { return $local_data; }
  my $filterExpiredMembers = shift;
  unless($filterExpiredMembers) { $filterExpiredMembers = 0; }
  my $data = $servicesAgent->getHashedHierarchicalData(service => $service->getId, facility => $facility->getId, filterExpiredMembers => $filterExpiredMembers, consentEval => $CONSENT_EVAL);
  logData $data, 'hashedHierarchicalData';
  return $data;
}

sub getHierarchicalData {
	if(defined $local_data) { return $local_data; }
	my $filterExpiredMembers = shift;
	unless($filterExpiredMembers) { $filterExpiredMembers = 0; }
	my $data = $servicesAgent->getHierarchicalData(service => $service->getId, facility => $facility->getId, filterExpiredMembers => $filterExpiredMembers);
	logData $data, 'hierarchicalData';
	return $data;
}

sub getFlatData {
	if(defined $local_data) { return $local_data; }
	my $filterExpiredMembers = shift;
	unless($filterExpiredMembers) { $filterExpiredMembers = 0; }
	my $data = $servicesAgent->getFlatData(service => $service->getId, facility => $facility->getId, filterExpiredMembers => $filterExpiredMembers);
	logData $data, 'flatData';
	return $data;
}

sub getHashedDataWithGroups {
	if(defined $local_data) { return $local_data; }
	my $filterExpiredMembers = shift;
	unless($filterExpiredMembers) { $filterExpiredMembers = 0; }
	my $data = $servicesAgent->getHashedDataWithGroups(service => $service->getId, facility => $facility->getId, filterExpiredMembers => $filterExpiredMembers, consentEval => $CONSENT_EVAL);
	logData $data, 'hashedDataWithGroups';
	return $data;
}

sub getDataWithGroups {
	if(defined $local_data) { return $local_data; }
	my $filterExpiredMembers = shift;
	unless($filterExpiredMembers) { $filterExpiredMembers = 0; }
	my $data = $servicesAgent->getDataWithGroups(service => $service->getId, facility => $facility->getId, filterExpiredMembers => $filterExpiredMembers);
	logData $data, 'dataWithGroups';
	return $data;
}

sub getDataWithVos {
	if(defined $local_data) { return $local_data; }
	my $filterExpiredMembers = shift;
	unless($filterExpiredMembers) { $filterExpiredMembers = 0; }
	my $data = $servicesAgent->getDataWithVos(service => $service->getId, facility => $facility->getId, filterExpiredMembers => $filterExpiredMembers);
	logData $data, 'dataWithVos';
	return $data;
}

#Returns directory for storing generated files
sub getDirectory {
	return $tmp_directory;
}

#Creates directory for destination from param. Returns path to that directory.
sub getDestinationDirectory {
	my $destination = shift;
	unless($destination) { die "getDestinationDirectory: no destination specified"; }
	my $path = "$tmp_directory_destination/$destination/";
	my $err;
	mkpath($path, { error => \$err } );
	if(@$err) { die "Can't mkpath( $tmp_directory_destination  )" };
	return $path;
}

sub createVersionFile {
	open VERSION_FILE, ">$tmp_directory" . "/VERSION";
	print VERSION_FILE $::PROTOCOL_VERSION, "\n";
	close VERSION_FILE;
}

sub createServicesFile {
	open SERVICE_FILE, ">$tmp_directory" . "/SERVICE";
	print SERVICE_FILE $::SERVICE_NAME, "\n";
	close SERVICE_FILE;
}

sub createFacilityNameFile($) {
	open FACILITY_NAME_FILE, ">$tmp_directory" . "/FACILITY";
	print FACILITY_NAME_FILE $_[0], "\n";
	close FACILITY_NAME_FILE;
}

return 1;
