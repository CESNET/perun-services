#!/usr/bin/perl
package perunDataGenerator;

use strict;
use warnings;
use perunServicesInit;
use Exporter 'import';

our $JSON_FORMAT = "json";
our @EXPORT = qw($JSON_FORMAT);

our $USER_ATTR_PREFIX = "urn:perun:user:";
our $USER_FACILITY_ATTR_PREFIX = "urn:perun:user_facility:";
our $MEMBER_ATTR_PREFIX = "urn:perun:member:";
our $MEMBER_RESOURCE_ATTR_PREFIX = "urn:perun:member_resource:";
our $RESOURCE_ATTR_PREFIX = "urn:perun:resource:";
our $FACILITY_ATTR_PREFIX = "urn:perun:facility:";

our $A_MEMBER_STATUS;                 *A_MEMBER_STATUS =                  \'urn:perun:member:attribute-def:core:status';

# Returns attribute definitions related to specified entity (entities) type(s)
sub getRequiredAttributesByType {
	my $requiredAttributesDefinitions = shift;
	my $attributePrefix = shift;
	my @requiredAttributes = ();

	foreach my $attrDef (@$requiredAttributesDefinitions) {
		my $o = index $attrDef->getNamespace, $attributePrefix;
		if ($o == 0) {
			push @requiredAttributes, $attrDef;
			next;
		}
	}

	return @requiredAttributes;
}

sub prepareMembersData {
	my $data = shift;
	my $userIds = shift;
	my $resourceId = shift;
	my $memberRequiredAttributes = shift;
	my $memberResourceRequiredAttributes = shift;

	my @members = ();
	foreach my $memberId ($data->getMemberIdsForResource(resource => $resourceId)) {
		my $memberData = {};
		my $perunUserId = $data->getUserIdForMember(member => $memberId);
		if (! exists $userIds->{$perunUserId}) {
			# user was skipped
			next;
		}
		$memberData->{"link_id"} = $userIds->{$perunUserId};

		foreach my $memberAttribute (@$memberRequiredAttributes) {
			my $attrValue = $data->getMemberAttributeValue(member => $memberId, attrName => $memberAttribute->getName);
			# In case there is an undefined boolean attribute, we have to change it to false
			if ($memberAttribute->getType eq "boolean" && !defined $attrValue) {
				$memberData->{$memberAttribute->getName} = \0;
			} else {
				$memberData->{$memberAttribute->getName} = $attrValue;
			}
		}

		foreach my $memberResourceAttribute (@$memberResourceRequiredAttributes) {
			my $attrValue = $data->getMemberResourceAttributeValue(member => $memberId, resource => $resourceId, attrName => $memberResourceAttribute->getName);
			# In case there is an undefined boolean attribute, we have to change it to false
			if ($memberResourceAttribute->getType eq "boolean" && !defined $attrValue) {
				$memberData->{$memberResourceAttribute->getName} = \0;
			} else {
				$memberData->{$memberResourceAttribute->getName} = $attrValue;
			}
		}

		push @members, $memberData;
	}
	return \@members;
}

# Prepares structure of user attributes
# If addLinkId is true, it will add "link_id" property which is returned in the usersIds structure as {"perunUserId": linkId}
sub prepareUsersData {
	my $data = shift;
	my $userRequiredAttributes = shift;
	my $userFacilityRequiredAttributes = shift;
	my $addLinkId = shift;

	my %usersIds = ();
	my $linkIdCounter = 0;
	my @users = ();
	foreach my $memberId ($data->getMemberIdsForFacility()) {

		if ($::SKIP_NON_VALID_MEMBERS) {
			next if $data->getMemberAttributeValue( member => $memberId, attrName => $A_MEMBER_STATUS ) ne 'VALID';
		}

		my $userId = $data->getUserIdForMember(member => $memberId);
		if (exists($usersIds{$userId})) {
			next;
		} else {
			$linkIdCounter++;
			$usersIds{$userId} = $linkIdCounter;
		}
		my $userData = {};

		foreach my $userAttribute (@$userRequiredAttributes) {
			my $attrValue = $data->getUserAttributeValue(member => $memberId, attrName => $userAttribute->getName);
			# In case there is an undefined boolean attribute, we have to change it to false
			if ($userAttribute->getType eq "boolean" && !defined $attrValue) {
				$userData->{$userAttribute->getName} = \0;
			} else {
				$userData->{$userAttribute->getName} = $attrValue;
			}
		}

		foreach my $userFacilityAttribute (@$userFacilityRequiredAttributes) {
			my $attrValue = $data->getUserFacilityAttributeValue(member => $memberId, attrName => $userFacilityAttribute->getName);
			# In case there is an undefined boolean attribute, we have to change it to false
			if ($userFacilityAttribute->getType eq "boolean" && !defined $attrValue) {
				$userData->{$userFacilityAttribute->getName} = \0;
			} else {
				$userData->{$userFacilityAttribute->getName} = $attrValue;
			}
		}

		if ($addLinkId) {
			$userData->{"link_id"} = $linkIdCounter;
		}
		push @users, $userData;
	}

	return (\@users, \%usersIds);
}

=c
Generate user and user_facility required attributes for each user into JSON file.
Subroutine uses perunServicesInit which REQUIRE access to $::SERVICE_NAME and $::PROTOCOL_VERSION.
This can be achieved by following lines in your main script: (for example)
local $::SERVICE_NAME = "passwd";
local $::PROTOCOL_VERSION = "3.0.0";
If not valid VO members should be skipped, member status attribute needs to be set on service and set
local $::SKIP_NON_VALID_MEMBERS = 1;
=cut
sub generateUsersDataInJSON {
	perunServicesInit::init;

	my $data = perunServicesInit::getHashedHierarchicalData;
	my $DIRECTORY = perunServicesInit::getDirectory;
	my ($users, $ids) = finalizeUsersData($data);
	my $fileName = "$DIRECTORY/$::SERVICE_NAME";
	open FILE, ">$fileName" or die "Cannot open $fileName: $! \n";
	print FILE JSON::XS->new->utf8->pretty->canonical->encode($users);
	close FILE or die "Cannot close $fileName: $! \n";

	perunServicesInit::finalize;
}

# Returns completed users data
sub finalizeUsersData {
	my $data = shift;
	my $agent = perunServicesInit->getAgent;
	my $attributesAgent = $agent->getAttributesAgent;
	my $servicesAgent = $agent->getServicesAgent;
	my $service = $servicesAgent->getServiceByName( name => $::SERVICE_NAME);

	my @requiredAttributesDefinitions = $attributesAgent->getRequiredAttributesDefinition(service => $service->getId);
	my @userRequiredAttributes = getRequiredAttributesByType(\@requiredAttributesDefinitions, $USER_ATTR_PREFIX);
	my @userFacilityRequiredAttributes = getRequiredAttributesByType(\@requiredAttributesDefinitions, $USER_FACILITY_ATTR_PREFIX);

	return prepareUsersData($data, \@userRequiredAttributes, \@userFacilityRequiredAttributes);
}

=c
Generate user, user_facility, member, member_resource, resource and facility required attributes into JSON file.
The result structure is:
{
"facility_attribute_name": "facility_attribute_value",
"users" => [{"user_attribute_name": "user_attribute_value",
             "link_id": id linking user to its members}]
"groups" => [{"resource_attribute_name": "resource_attribute_value",
              "members": [{"member_attribute_name": "member_attribute_value",
                         "link_id": id of user this member belongs to}]}]
}
Subroutine uses perunServicesInit which REQUIRE access to $::SERVICE_NAME and $::PROTOCOL_VERSION.
This can be achieved by following lines in your main script: (for example)
local $::SERVICE_NAME = "passwd";
local $::PROTOCOL_VERSION = "3.0.0";
If not valid VO members should be skipped, member status attribute needs to be set on service and set
local $::SKIP_NON_VALID_MEMBERS = 1;
=cut
sub generateMemberUsersDataInJson {
	perunServicesInit::init;

	my $DIRECTORY = perunServicesInit::getDirectory;
	my $data = perunServicesInit::getHashedHierarchicalData;
	my $result = finalizeMemberUsersData($data);
	my $fileName = "$DIRECTORY/$::SERVICE_NAME";
	open FILE, ">$fileName" or die "Cannot open $fileName: $! \n";
	print FILE JSON::XS->new->utf8->pretty->canonical->encode($result);
	close FILE or die "Cannot close $fileName: $! \n";

	perunServicesInit::finalize;
}

# Returns completed member-users data
sub finalizeMemberUsersData {
	my $data = shift;
	my $agent = perunServicesInit->getAgent;
	my $attributesAgent = $agent->getAttributesAgent;
	my $servicesAgent = $agent->getServicesAgent;
	my $service = $servicesAgent->getServiceByName( name => $::SERVICE_NAME);

	my @requiredAttributesDefinitions = $attributesAgent->getRequiredAttributesDefinition(service => $service->getId);

	my @userRequiredAttributes = getRequiredAttributesByType(\@requiredAttributesDefinitions, $USER_ATTR_PREFIX);
	my @userFacilityRequiredAttributes = getRequiredAttributesByType(\@requiredAttributesDefinitions, $USER_FACILITY_ATTR_PREFIX);
	my ($users, $userIds) = prepareUsersData($data, \@userRequiredAttributes, \@userFacilityRequiredAttributes, 1);

	my @facilityRequiredAttributes = getRequiredAttributesByType(\@requiredAttributesDefinitions, $FACILITY_ATTR_PREFIX);
	my @resourceRequiredAttributes = getRequiredAttributesByType(\@requiredAttributesDefinitions, $RESOURCE_ATTR_PREFIX);
	my @memberRequiredAttributes = getRequiredAttributesByType(\@requiredAttributesDefinitions, $MEMBER_ATTR_PREFIX);
	my @memberResourceRequiredAttributes = getRequiredAttributesByType(\@requiredAttributesDefinitions, $MEMBER_RESOURCE_ATTR_PREFIX);

	my $result = {};
	$result->{"users"} = $users;
	$result->{"groups"} = ();

	foreach my $facilityAttribute (@facilityRequiredAttributes) {
		my $attrValue = $data->getFacilityAttributeValue(attrName => $facilityAttribute->getName);
		# In case there is an undefined boolean attribute, we have to change it to false
		if ($facilityAttribute->getType eq "boolean" && !defined $attrValue) {
			$result->{$facilityAttribute->getName} = \0;
		} else {
			$result->{$facilityAttribute->getName} = $attrValue;
		}
	}

	foreach my $resourceId ($data->getResourceIds()) {
		my $resource = {};
		foreach my $resourceAttribute (@resourceRequiredAttributes) {
			my $attrValue = $data->getResourceAttributeValue(resource => $resourceId, attrName => $resourceAttribute->getName);
			# In case there is an undefined boolean attribute, we have to change it to false
			if ($resourceAttribute->getType eq "boolean" && !defined $attrValue) {
				$resource->{$resourceAttribute->getName} = \0;
			} else {
				$resource->{$resourceAttribute->getName} = $attrValue;
			}
		}
		$resource->{"members"} = prepareMembersData($data, $userIds, $resourceId, \@memberRequiredAttributes, \@memberResourceRequiredAttributes);
		push @{$result->{"groups"}}, $resource;
	}

	return $result;
}

return 1;
