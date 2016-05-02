#!/usr/bin/perl

use strict;
use warnings;
use perunServicesInit;
use perunServicesUtils;
use open qw/:std :utf8/;
use Data::Dumper;

local $::SERVICE_NAME = "redmine";
local $::PROTOCOL_VERSION = "3.0.0";

perunServicesInit::init;
my $DIRECTORY = perunServicesInit::getDirectory;
my $data = perunServicesInit::getHierarchicalData;

#forward declaration
sub processUsers;
sub processProjects;
sub processMemberships;

#Constants
our $A_USER_LOGIN;                *A_USER_LOGIN =            \'urn:perun:user_facility:attribute-def:virt:login';
our $A_USER_EMAIL;                *A_USER_EMAIL =            \'urn:perun:user:attribute-def:def:preferredMail';
our $A_USER_EPPNS;                *A_USER_EPPNS =            \'urn:perun:user:attribute-def:virt:eduPersonPrincipalNames';
our $A_USER_FIRSTNAME;            *A_USER_FIRSTNAME =        \'urn:perun:user:attribute-def:core:firstName';
our $A_USER_LASTNAME;             *A_USER_LASTNAME =         \'urn:perun:user:attribute-def:core:lastName';

our $A_RESOURCE_PROJECTID;        *A_RESOURCE_PROJECTID =    \'urn:perun:resource:attribute-def:def:redmineProjectID';
our $A_RESOURCE_PROJECTNAME;      *A_RESOURCE_PROJECTNAME =  \'urn:perun:resource:attribute-def:def:redmineProjectName';
our $A_RESOURCE_DESCRIPTION;      *A_RESOURCE_DESCRIPTION =  \'urn:perun:resource:attribute-def:def:redmineProjectDescription';
our $A_RESOURCE_ROLE;             *A_RESOURCE_ROLE =         \'urn:perun:resource:attribute-def:def:redmineRole';

our $userStruc = {};
our $u_email = {};
our $u_firstName = {};
our $u_lastName = {};
our $u_eppns = {};

our $membershipStruc = {};
our $r_projectID = {};
our $r_roles = {};

our $projectStruc = {};
our $r_projectName = {};
our $r_description = {};
our $r_isPublic = {};

my $fileUsers = $DIRECTORY . "users.csv";
my $fileProjects = $DIRECTORY . "projects.csv";
my $fileMemberships = $DIRECTORY . "membership.csv";

foreach my $rData ($data->getChildElements) {
	processProjects $rData;
}

# PROJECTS: project_id project_name description is_public
open FILE_PROJECTS,">$fileProjects" or die "Cannot open $fileProjects: $! \n";
foreach my $projectID (sort keys %$projectStruc) {
	print FILE_PROJECTS "$projectID, $projectStruc->{$projectID}->{$r_projectName}, $projectStruc->{$projectID}->{$r_description}, $projectStruc->{$projectID}->{$r_isPublic}\n";
}
close (FILE_PROJECTS) or die "Cannot close $fileProjects: $! \n";

# USERS: first_name last_name login e-mail eppns
open FILE_USERS,">$fileUsers" or die "Cannot open $fileUsers: $! \n";
foreach my $login (sort keys %$userStruc) {
	print FILE_USERS "$userStruc->{$login}->{$u_firstName}, $userStruc->{$login}->{$u_lastName}, $login, $userStruc->{$login}->{$u_email}, ";
	print FILE_USERS join( ';', @{$userStruc->{$login}->{$u_eppns}} );
	print FILE_USERS "\n";
}
close (FILE_USERS) or die "Cannot close $fileUsers: $! \n";

# MEMBERSHIPS: project_id description roles
open FILE_MEMBERSHIPS,">$fileMemberships" or die "Cannot open $fileMemberships: $! \n";
foreach my $login (sort keys %$membershipStruc){
	print FILE_MEMBERSHIPS "$membershipStruc->{$login}->{$r_projectID}, $login, ";
	print FILE_MEMBERSHIPS join(";", @{$membershipStruc->{$login}->{$r_roles}});
	print FILE_MEMBERSHIPS "\n";
}
close (FILE_MEMBERSHIPS) or die "Cannot close $fileMemberships: $! \n";

perunServicesInit::finalize;


##############################################################################
#   Only subs definitions down there
##############################################################################
## creates structure for projects.csv file
sub processProjects {
	my $project = shift;

	my %resourceAttributes = attributesToHash $project->getAttributes;

	my $projectID =		$resourceAttributes{$A_RESOURCE_PROJECTID};
	my $projectName =	$resourceAttributes{$A_RESOURCE_PROJECTNAME};
	my $description =	$resourceAttributes{$A_RESOURCE_DESCRIPTION};
	my $isPublic =		"True";
	my @roles =		$resourceAttributes{$A_RESOURCE_ROLE};

	if(exists $projectStruc->{$projectID} && $projectStruc->{$projectID}->{$r_projectName} != $projectName){
		die "Cannot exists more projects with same projectID and with different name! \n";
	}

	$projectStruc->{$projectID}->{$r_projectName} = $projectName;
	$projectStruc->{$projectID}->{$r_description} = $description;
	$projectStruc->{$projectID}->{$r_isPublic}    = $isPublic;

		foreach my $memberData ($project->getChildElements) {
			processUsers $projectID, $memberData ,@roles;
		}
}

## creates structure for users.csv file
sub processUsers {
	my ($projectID, $memberData ,@roles) = @_;

	my %memberAttributes = attributesToHash $memberData->getAttributes;
	my $firstName = $memberAttributes{$A_USER_FIRSTNAME};
	my $lastName = $memberAttributes{$A_USER_LASTNAME};
	my $login = $memberAttributes{$A_USER_LOGIN};
	my $email = $memberAttributes{$A_USER_EMAIL};
	my @eppns = @{$memberAttributes{$A_USER_EPPNS}};

	$userStruc->{$login}->{$u_firstName} = $firstName;
	$userStruc->{$login}->{$u_lastName} = $lastName;
	$userStruc->{$login}->{$u_email} = $email;
	@{$userStruc->{$login}->{$u_eppns}} = @eppns;

	processMemberships $login, $projectID, @roles;
}


## creates structure for memberships.csv file
sub processMemberships {
	my ($login, $projectID, @roles) = @_;
	$membershipStruc->{$login}->{$r_projectID} = $projectID;
	@{$membershipStruc->{$login}->{$r_roles}} = @roles;
}
