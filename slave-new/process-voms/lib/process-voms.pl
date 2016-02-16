#!/usr/bin/perl

# initialize parser and read the file
use XML::Simple;
use Text::CSV;
use Data::Dumper;
$vos = XMLin( '-' );
my $csv = Text::CSV->new({ sep_char => ',' });

sub listToHashes {
	my @hashes;
	foreach $line (@_) {
		chomp($line);
		$csv->parse($line);
		my @components = $csv->fields();
		my %mbr= ( 'dn' => "${components[0]}",'ca' => "${components[1]}", 'mail' => "${components[2]}" );
		push( @hashes, \%mbr );
	}
	return \@hashes;
}



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
#	print "Roles:";
#	foreach $role (@roles_current) {
#		printf "\t%s\n",$role;
#	}
#	print "Groups:";
#	foreach $group (@groups_current) {
#		printf "\t%s\n",$group;
#	}
#	print "Users:";
#	foreach $user (@users_current) {
#		printf "\t%s\n",$user;
#	}

	#Collect current Group Membership and Role assignment
	my %groupRoles;
	my %groupMembers;
	foreach $group (@groups_current) {
		#Store members
		$groupMembers{"$group"}=listToHashes(`voms-admin --vo ${name} list-members "${group}"`);

		#Role Membership
		foreach $role (@roles_current) {
			$groupRoles{"$group"}{"$role"}=listToHashes(`voms-admin --vo ${name} list-users-with-role "${group}" "${role}"`);
	        }
	}

	foreach $group (@groups_current) {
		foreach $user (@{$groupMembers{"$group"}}) {
			printf "G\t%s\t%s\n",$group,$user->{'mail'};
		}
		foreach $role (@roles_current) {
			foreach $user (@{$groupRoles{"$group"}{"$role"}}) {
				printf " R\t%s\t%s\t%s\n",$group,$role,$user->{'mail'};
			}
		}
	}

	#Collect all lists from voms-admin

#	print(Dumper($vo));
#	foreach my $user (@{$vo->{'users'}->{'user'}}) {
#		printf "\t\"%s\"\n",$user->{'DN'};
#		printf "\t\"%s\"\n\t\t\"%s\"\n",$user->{'DN'},$user->{'CA'};
#	}
}
