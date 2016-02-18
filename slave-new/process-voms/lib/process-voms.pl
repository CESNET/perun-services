#!/usr/bin/perl

# initialize parser and read the file
use XML::Simple;
use Text::CSV;
use Data::Dumper;
$vos = XMLin( '-' );
my $csv = Text::CSV->new({ sep_char => ',' });

### listToHashes accepts a three-column CSV and produces an array of hashes with the following structure:
#	DN	VO Member DN
#	CA	Certificate Authority that vouches for the member
#	email	The email address of the user
sub listToHashes {
	my @hashes;
	foreach $line (@_) {
		chomp($line);
		$csv->parse($line);
		my @components = $csv->fields();
		my %mbr= ( 'DN' => "${components[0]}",'CA' => "${components[1]}", 'email' => "${components[2]}" );
		push( @hashes, \%mbr );
	}
	return \@hashes;
}


# Main parsing loop for the input XML file
foreach my $name (keys %{$vos->{'vo'}}) { # Iterating through individual VOs in the XML
	$vo=$vos->{'vo'}->{$name};
	printf "---\nVO:\t${name}\n";

	#Collect lists from voms-admin
	my @groups_current=`voms-admin --vo ${name} list-groups`;
	chomp(@groups_current);
	s/^\s*// for @groups_current;

	my @roles_current=`voms-admin --vo ${name} list-roles`;
	chomp(@roles_current);
	s/^\s*Role=// for @roles_current;

	my @users_current=`voms-admin --vo ${name} list-users`;
	chomp(@users_current);

	#Collect current Group Membership and Role assignment
	my %groupRoles_current;		# Current assignment of users to (per group) roles
	my %groupMembers_current;	# Current membership in groups (pure, disregarding roles)
	foreach $group (@groups_current) {
		#Store members
		$groupMembers_current{"$group"}=listToHashes(`voms-admin --vo ${name} list-members "${group}"`);

		#Role Membership
		foreach $role (@roles_current) {
			$groupRoles_current{"$group"}{"$role"}=listToHashes(`voms-admin --vo ${name} list-users-with-role "${group}" "${role}"`);
	        }
	}

	foreach $group (@groups_current) {
		foreach $user (@{$groupMembers_current{"$group"}}) {
			printf "=G\t%s\t%s\n",$group,$user->{'DN'};
		}
		foreach $role (@roles_current) {
			foreach $user (@{$groupRoles_current{"$group"}{"$role"}}) {
				printf "= R\t%s\t%s\t%s\n",$group,$role,$user->{'DN'};
			}
		}
	}



	# Produce comparable data structure from input data
#	print(Dumper($vo));
	my %groupRoles_toBe;		# Desired assignment of users to (per group) roles
	my %groupMembers_toBe;		# Desired membership in groups (pure, disregarding roles)
	my @groups_toBe = ( "/$name" );	# Desired list of groups
	my @roles_toBe;			# Desired list of roles
	foreach $user (@{$vo->{'users'}->{'user'}}) {
		my %theUser= ( 'CA' => "$user->{'CA'}",'DN' => "$user->{'DN'}", 'email' => "$user->{'email'}" );
		push( @{$groupMembers_toBe{"/$name"}}, \%theUser ); #Add user to root group (make them a member)
		foreach $group ($user->{'groups'}->{'group'}) {
			if (defined $group->{'name'}) {
				push(@groups_toBe, "/$name/$group->{'name'}") unless grep{$_ eq "/$name/$group->{'name'}"} @groups_toBe;
				push(@{$groupMembers_toBe{"/$name/$group->{'name'}"}}, \%theUser);
				foreach $role (@{$group->{'roles'}->{'role'}}) {
					push(@roles_toBe, "$role") unless grep{$_ eq "$role"} @roles_toBe;
					push(@{$groupRoles_toBe{"/$name/$group->{'name'}"}{"$role"}}, \%theUser);
				}
			}
		}
	}






        foreach $group (@groups_toBe) {
                foreach $user (@{$groupMembers_toBe{"$group"}}) {
                        printf "+G\t%s\t%s\n",$group,$user->{'DN'};
                }
                foreach $role (@roles_toBe) {
                        foreach $user (@{$groupRoles_toBe{"$group"}{"$role"}}) {
                                printf "+ R\t%s\t%s\t%s\n",$group,$role,$user->{'DN'};
                        }
                }
        }

}
