#!/usr/bin/perl
package perunDataGenerator;

use strict;
use warnings;
use perunServicesInit;
use Exporter 'import';

our $JSON_FORMAT = "json";
our @EXPORT = qw($JSON_FORMAT);

our $A_MEMBER_STATUS;                 *A_MEMBER_STATUS =                  \'urn:perun:member:attribute-def:core:status';

# Generate user and user_facility required attributes for each user into JSON file.
# Subroutine uses perunServicesInit which REQUIRE access to $::SERVICE_NAME and $::PROTOCOL_VERSION.
# This can be achieved by following lines in your main script: (for example)
# local $::SERVICE_NAME = "passwd";
# local $::PROTOCOL_VERSION = "3.0.0";
# If not valid VO members should be skipped, member status attribute needs to be set on service and set
# local $::SKIP_NON_VALID_MEMBERS = 1;
sub generateUsersDataInJSON {
	perunServicesInit::init;

	my $DIRECTORY = perunServicesInit::getDirectory;
	my $data = perunServicesInit::getHashedHierarchicalData;
	my $agent = perunServicesInit->getAgent;
	my $attributesAgent = $agent->getAttributesAgent;
	my $servicesAgent = $agent->getServicesAgent;
	my $service = $servicesAgent->getServiceByName( name => $::SERVICE_NAME);

	my @requiredAttributesDefinitions = $attributesAgent->getRequiredAttributesDefinition(service => $service->getId);
	my @userRequiredAttributes = ();
	my @userFacilityRequiredAttributes = ();
	foreach my $attrDef (@requiredAttributesDefinitions) {
		# if attribute's namespace starts with "urn:perun:user:"
		my $o = index $attrDef->getNamespace, "urn:perun:user:";
		if ($o == 0) {
			push @userRequiredAttributes, $attrDef;
			next;
		}
		$o = index $attrDef->getNamespace, "urn:perun:user_facility:";
		if ($o == 0) {
			push @userFacilityRequiredAttributes, $attrDef;
			next;
		}
	}
	my @users;

	####### prepare data ######################
	my %usersIds = ();
	foreach my $memberId ($data->getMemberIdsForFacility()) {

		if ($::SKIP_NON_VALID_MEMBERS) {
			next if $data->getMemberAttributeValue( member => $memberId, attrName => $A_MEMBER_STATUS ) ne 'VALID';
		}

		my $userId = $data->getUserIdForMember(member => $memberId);
		if (exists($usersIds{$userId})) {
			next;
		} else {
			$usersIds{$userId} = 0;
		}
		my $userData = {};

		foreach my $userAttribute (@userRequiredAttributes) {
			my $attrValue = $data->getUserAttributeValue(member => $memberId, attrName => $userAttribute->getName);
			# In case there is an undefined boolean attribute, we have to change it to false
			if ($userAttribute->getType eq "boolean" && !defined $attrValue) {
				$userData->{$userAttribute->getName} = \0;
			} else {
				$userData->{$userAttribute->getName} = $attrValue;
			}
		}

		foreach my $userFacilityAttribute (@userFacilityRequiredAttributes) {
			my $attrValue = $data->getUserFacilityAttributeValue(member => $memberId, attrName => $userFacilityAttribute->getName);
			# In case there is an undefined boolean attribute, we have to change it to false
			if ($userFacilityAttribute->getType eq "boolean" && !defined $attrValue) {
				$userData->{$userFacilityAttribute->getName} = \0;
			} else {
				$userData->{$userFacilityAttribute->getName} = $attrValue;
			}
		}
		push @users, $userData;
	}

	####### output file ######################
	my $fileName = "$DIRECTORY/$::SERVICE_NAME";
	open FILE, ">$fileName" or die "Cannot open $fileName: $! \n";
	print FILE JSON::XS->new->utf8->pretty->canonical->encode(\@users);
	close FILE or die "Cannot close $fileName: $! \n";

	perunServicesInit::finalize;
}

return 1;
