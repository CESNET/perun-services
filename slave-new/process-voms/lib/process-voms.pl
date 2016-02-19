#!/usr/bin/perl

# initialize parser and read the file
use XML::Simple;
use Text::CSV;
use Data::Dumper;
use Array::Utils qw(:all);
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


###  effectCall runs actual voms-admin commands. It accepts three arguments:
#	$command	The shell command to run
#	$debugMsg	Message to log on execution
#	$failMsg	Message to log in case of failure
sub effectCall {
	$command = $_[0];
	$debugMsg = $_[1];
	$failMsg = $_[2];

	print "$command\n";
}

# Main parsing loop for the input XML file
foreach my $name (keys %{$vos->{'vo'}}) { # Iterating through individual VOs in the XML
	$vo=$vos->{'vo'}->{$name};
#	printf "---\nVO:\t${name}\n";

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

#	foreach $group (@groups_current) {
#		foreach $user (@{$groupMembers_current{"$group"}}) {
#			printf "=G\t%s\t%s\n",$group,$user->{'DN'};
#		}
#		foreach $role (@roles_current) {
#			foreach $user (@{$groupRoles_current{"$group"}{"$role"}}) {
#				printf "= R\t%s\t%s\t%s\n",$group,$role,$user->{'DN'};
#			}
#		}
#	}



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




	# Make comparisons
	my @groupsToDelete = array_minus( @groups_current, @groups_toBe );
	my @groupsToCreate = array_minus( @groups_toBe, @groups_current );

	my @rolesToDelete = array_minus( @roles_current, @roles_toBe );
	my @rolesToCreate = array_minus( @roles_toBe, @roles_current );

	my %membersToAdd;
	my %membersToAdd;
	my %rolesToAssign;
	my %rolesToDismiss;
        foreach $group (@groups_toBe) {
		@{$membersToRemove{"$group"}} = array_minus(@{$groupMembers_current{"$group"}}, @{$groupMembers_toBe{"$group"}});
		@{$membersToAdd{"$group"}} = array_minus(@{$groupMembers_toBe{"$group"}}, @{$groupMembers_current{"$group"}});
		foreach $role (@roles_toBe) {
			@{$rolesToAssign{"$group"}{"$role"}} = array_minus(@{$groupRoles_toBe{"$group"}{"$role"}}, @{$groupRoles_current{"$group"}{"$role"}});
			@{$rolesToDismiss{"$group"}{"$role"}} = array_minus(@{$groupRoles_current{"$group"}{"$role"}}, @{$groupRoles_toBe{"$group"}{"$role"}});
		}
        }




#        foreach $group (@groups_toBe) {
#                foreach $user (@{$groupMembers_toBe{"$group"}}) {
#                        printf "+G\t%s\t%s\n",$group,$user->{'DN'};
#                }
#                foreach $role (@roles_toBe) {
#                        foreach $user (@{$groupRoles_toBe{"$group"}{"$role"}}) {
#                                printf "+ R\t%s\t%s\t%s\n",$group,$role,$user->{'DN'};
#                        }
#                }
#        }


	# Effect changes
	# 1. create / delete groups
	foreach $group (@groupsToDelete) {
		effectCall "voms-admin --vo $name delete-group \"$group\""
	}
	foreach $group (@groupsToCreate) {
		effectCall "voms-admin --vo $name create-group \"$group\""
	}

	# 2. create / delete roles
	foreach $role (@rolesToDelete) {
		effectCall "voms-admin --vo $name delete-role \"$role\""
	}
	foreach $role (@rolesToCreate) {
		effectCall "voms-admin --vo $name create-role \"$role\""
	}

	# 3. add members to/remove members from groups
	foreach $group (@groups_toBe) {
		foreach $user (@{$membersToAdd{"$group"}}) {
			effectCall "voms-admin --nousercert --vo $name add-member \"$group\" \"$user->{'DN'}\" \"$user->{'CA'}\"";
		}
		foreach $user (@{$membersToRemove{"$group"}}) {
			effectCall "voms-admin --nousercert --vo $name remove-member \"$group\" \"$user->{'DN'}\" \"$user->{'CA'}\"";
		}
	}

	# 4. assign/dismiss roles
	foreach $group (@groups_toBe) {
		foreach $role (@roles_toBe) {
			foreach $user (@{$rolesToAssign{"$group"}{"$role"}}) {
				effectCall "voms-admin --nousercert --vo $name assign-role \"$group\" \"$role\" \"$user->{'DN'}\" \"$user->{'CA'}\"";
			}
			foreach $user (@{$rolesToDismiss{"$group"}{"$role"}}) {
				effectCall "voms-admin --nousercert --vo $name dismiss-role \"$group\" \"$role\" \"$user->{'DN'}\" \"$user->{'CA'}\"";
			}
		}
	}



}
