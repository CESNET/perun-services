#!/usr/bin/perl

# initialize parser and read the file
use XML::Simple;
use Data::Dumper;
$vos = XMLin( '-' );

#print(Dumper($vos));

# Main parsing loop for the input XML file
foreach my $name (keys %{$vos->{'vo'}}) { # Iterating through individual VOs in the XML
	$vo=$vos->{'vo'}->{$name};
	printf "---\nVO:\t${name}\n";

	@groups_current=`voms-admin --vo ${name} list-groups`;
	chomp(@groups_current);
	s/^\s*// for @groups_current;

	@roles_current=`voms-admin --vo ${name} list-roles`;
	chomp(@roles_current);
	s/^\s*Role=// for @roles_current;

	@users_current=`voms-admin --vo ${name} list-users`;
	chomp(@users_current);
	print "Roles:";
	foreach $role (@roles_current) {
		printf "\t%s\n",$role;
	}
	print "Groups:";
	foreach $group (@groups_current) {
		printf "\t%s\n",$group;
	}
	print "Users:";
	foreach $user (@users_current) {
		printf "\t%s\n",$user;
	}

	#Collect all lists from voms-admin

#	print(Dumper($vo));
	foreach my $user (@{$vo->{'users'}->{'user'}}) {
#		printf "\t\"%s\"\n\t\t\"%s\"\n",$user->{'DN'},$user->{'CA'};
	}
}
