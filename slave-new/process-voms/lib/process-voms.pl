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


### logMsg accepts a string, prints it on STDERR and logs it with syslog
#	$message	Message to log
sub logMsg {
	$message = shift;

	printf "$message\n";
}

### effectCall runs actual voms-admin commands. It accepts three arguments:
#	$command	The shell command to run
#	$debugMsg	Message to log on execution
sub effectCall {
	$command = shift;
	$debugMsg = shift;

	print "$command\n";
	logMsg "$debugMsg";
}

### knownCA indicates whether a given CA is known to the VOMS server. It accepts the user structure
#	%user		The user whose CA should be checked (DN, CA, email)
#	%list		Reference to the list of known CAs
sub knownCA {
	%user = shift;
	$list = shift;

        if( $user->{'CA'} ~~ @{$list}) {
		return true;
	} else {
		logMsg "Unknown CA \"$user->{'CA'}\" requested with user \"$user->{'DN'}\"";
		return false;
	}
}

# Main parsing loop for the input XML file
foreach my $name (keys %{$vos->{'vo'}}) { # Iterating through individual VOs in the XML
	$vo=$vos->{'vo'}->{$name};

	#Collect lists from voms-admin
	my @groups_current=`voms-admin --vo ${name} list-groups`;
	if ( $? != 0 ) {
		logMsg "Failed listing groups in VO \"$name\". Error Code $?, original message from voms-admin: @groups_current";
		next;
	}
	chomp(@groups_current);
	s/^\s*// for @groups_current;

	my @roles_current=`voms-admin --vo ${name} list-roles`;
	if ( $? != 0 ) {
		logMsg "Failed listing roles in VO \"$name\". Error Code $?, original message from voms-admin: @groups_current";
		next;
	}
	chomp(@roles_current);
	s/^\s*Role=// for @roles_current;

	my @cas=`voms-admin --vo ${name} list-cas`;
	if ( $? != 0 ) {
		logMsg "Failed listing known CAs for VO \"$name\". Error Code $?, original message from voms-admin: @groups_current";
		next;
	}
	chomp(@cas);

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



	# Produce comparable data structure from input data
	my %groupRoles_toBe;		# Desired assignment of users to (per group) roles
	my %groupMembers_toBe;		# Desired membership in groups (pure, disregarding roles)
	my @groups_toBe = ( "/$name" );	# Desired list of groups
	my @roles_toBe;			# Desired list of roles
	foreach $user (@{$vo->{'users'}->{'user'}}) {
		next unless knownCA($user->{'CA'}, \@cas);
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




	# Effect changes
	# 1. create / delete groups
	foreach $group (@groupsToDelete) {
		effectCall "voms-admin --vo $name delete-group \"$group\"",
		"deleting Group \"$group\" from VO \"$name\"";
	}
	foreach $group (@groupsToCreate) {
		effectCall "voms-admin --vo $name create-group \"$group\"",
		"creating Group \"$group\" in VO \"$name\"";
	}

	# 2. create / delete roles
	foreach $role (@rolesToDelete) {
		effectCall "voms-admin --vo $name delete-role \"$role\"",
		"deleting Role \"$role\" from VO \"$name\".";
	}
	foreach $role (@rolesToCreate) {
		effectCall "voms-admin --vo $name create-role \"$role\"",
		"creating Role \"$role\" in VO \"$name\".";
	}

	# 3. add members to/remove members from groups
	foreach $group (@groups_toBe) {
		foreach $user (@{$membersToAdd{"$group"}}) {
			effectCall "voms-admin --nousercert --vo $name add-member \"$group\" \"$user->{'DN'}\" \"$user->{'CA'}\"",
			"adding user \"$user->{'DN'}\" to Group \"$group\" in VO \"$name\".";
		}
		foreach $user (@{$membersToRemove{"$group"}}) {
			effectCall "voms-admin --nousercert --vo $name remove-member \"$group\" \"$user->{'DN'}\" \"$user->{'CA'}\"",
			"removing user \"$user->{'DN'}\" from Group \"$group\" in VO \"$name\".";
		}
	}

	# 4. assign/dismiss roles
	foreach $group (@groups_toBe) {
		foreach $role (@roles_toBe) {
			foreach $user (@{$rolesToAssign{"$group"}{"$role"}}) {
				effectCall "voms-admin --nousercert --vo $name assign-role \"$group\" \"$role\" \"$user->{'DN'}\" \"$user->{'CA'}\"",
				"assigning Role \"$role\" to user \"$user->{'DN'}\" for Group \"$group\" in VO \"$name\"";
			}
			foreach $user (@{$rolesToDismiss{"$group"}{"$role"}}) {
				effectCall "voms-admin --nousercert --vo $name dismiss-role \"$group\" \"$role\" \"$user->{'DN'}\" \"$user->{'CA'}\"",
				"stripping user \"$user->{'DN'}\" of Role \"$role\" for Group \"$group\" in VO \"$name\"";
			}
		}
	}



}
