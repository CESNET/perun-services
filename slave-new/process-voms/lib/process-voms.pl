#!/usr/bin/perl

# Potentially useful VOMS links
#https://voms2.cern.ch:8443/voms/alice/services/VOMSAdmin?method=listSubGroups
#https://voms2.cern.ch:8443/voms/alice/services/VOMSAdmin?method=listSubGroups&groupname=/alice/alarm
#https://voms2.cern.ch:8443/voms/alice/services/VOMSAdmin?method=listMembers&groupname=/alice/alarm
#https://voms2.cern.ch:8443/voms/alice/services/VOMSAdmin?method=listRoles

# initialize parser and read the file
use XML::Simple;
use Data::Dumper;
$vos = XMLin( '-' );

#print(Dumper($vos));

printf "-------\n";

# serialize the structure
foreach my $name (keys $vos->{'vo'}) {
	$vo=$vos->{'vo'}->{$name};
	printf "${name}\n";
	foreach my $user (values $vo->{'users'}->{'user'}) {
		printf "\t\"%s\" \"%s\"\n",$user->{'DN'},$user->{'CA'};
	}
}
