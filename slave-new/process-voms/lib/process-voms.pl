#!/usr/bin/perl

# initialize parser and read the file
use XML::Simple;
use Data::Dumper;
$vos = XMLin( '-' );

#print(Dumper($vos));

# Main parsing loop for the input XML file
foreach my $name (keys %{$vos->{'vo'}}) { # Iterating through individual VOs in the XML
	$vo=$vos->{'vo'}->{$name};

	printf "${name}\n";
	#Collect all lists from voms-admin

#	print(Dumper($vo));
	foreach my $user (@{$vo->{'users'}->{'user'}}) {
		printf "\t\"%s\" \"%s\"\n",$user->{'DN'},$user->{'CA'};
	}
}
