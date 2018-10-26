#!/usr/bin/perl
package perunDataGenerator;

use strict;
use warnings;
use perunServicesInit;
use Exporter 'import';

our $JSON_FORMAT = "json";
our @EXPORT = qw($JSON_FORMAT);

# Generate user and user_facility required attributes for each user into JSON file.
# Subroutine uses perunServicesInit which REQUIRE access to $::SERVICE_NAME and $::PROTOCOL_VERSION.
# This can be achieved by following lines in your main script: (for example)
# local $::SERVICE_NAME = "passwd";
# local $::PROTOCOL_VERSION = "3.0.0";
sub generateUsersDataInJSON {
	perunServicesInit::init;

	my $DIRECTORY = perunServicesInit::getDirectory;
	my $data = perunServicesInit::getFlatData;
	my @users;

	####### prepare data ######################
	foreach my $user (($data->getChildElements)[1]->getChildElements) {
		my $userData = {};
		foreach my $uAttribute ($user->getAttributes) {
			# In case there is an undefined boolean attribute, we have to change it to false
			if ($uAttribute->getType eq "boolean" && !defined $uAttribute->getValue) {
				$userData->{$uAttribute->getName} = \0;
			} else {
				$userData->{$uAttribute->getName} = $uAttribute->getValue;
			}
		}
		push @users, $userData;
	}

	####### output file ######################
	my $fileName = "$DIRECTORY/$::SERVICE_NAME";
	open FILE, ">$fileName" or die "Cannot open $fileName: $! \n";
	print FILE JSON::XS->new->utf8->pretty->encode(\@users);
	close FILE or die "Cannot close $fileName: $! \n";

	perunServicesInit::finalize;
}

return 1;
