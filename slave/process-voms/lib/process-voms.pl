#!/usr/bin/perl

# initialize parser and read the file
use Sys::Syslog;
use XML::Simple;
use Text::CSV;
use Array::Utils qw(:all);
use JSON::XS;
use File::Basename;
use File::Path qw/make_path/;
my $vos = XMLin( '-',
	ForceArray => [ 'role', 'group', 'user', 'vo' ],
#	GroupTags => { role => 'roles', groups => 'group', users => 'user', vos => 'vo' },
	KeyAttr => [] );
my $csv = Text::CSV->new({ sep_char => ',' });

$attributeStatusFilePrefix = "/var/lib/perun/process-voms/process-voms-attributes-";
my $attributeStatusDir = dirname($attributeStatusFilePrefix);
make_path($attributeStatusDir) unless (-e $attributeStatusDir);
my $etcDir = "/etc/voms-admin";
my $etcPropertyFilename = "service.properties";

### serialize is used to turn an array of hash references into a manageable structure
sub serialize {
	JSON::XS->new->relaxed(0)->ascii(1)->canonical(1)->encode($_[0]);
}

### array_minus_deep is a replacement for array_minus that expands hash references
sub array_minus_deep(\@\@) {
	my ($array,$minus) = @_;

	my %minus = map( ( serialize($_) => 1 ), @$minus );
	grep !$minus{ serialize($_) }, @$array
}

### getCN extracts a CN from DN. It accepts one aregument:
#	DN	DN to process
sub getCN {
	my $cn = shift;
	$cn =~ s/.*\/CN=//;
	$cn =~ s/\/.*//;
	return $cn;
}

### normalizeEmail applies the same normalization replacement on user DNs as voms-admin itself
#   Calling normalizeEmail() works around bugs in voms-admin wherein the normalization function
#   is not called in some cases
#       DN      DN to process
sub normalizeEmail {
	my $normalized = shift;
	$normalized =~ s/\/(E|e|((E|e|)(mail|mailAddress|mailaddress|MAIL|MAILADDRESS)))=/\/Email=/;
	return $normalized
}

### normalizeUID applies the same normalization replacement on user DNs as voms-admin itself
#   Calling normalizeUID() works around bugs in voms-admin wherein the normalization function
#   is not called in some cases
#       DN      DN to process
sub normalizeUID {
	my $normalized = shift;
	$normalized =~ s/\/(UserId|USERID|userId|userid|uid|Uid)=/\/UID=/;
	return $normalized
}

### listToHashes accepts a three-column CSV and produces an array of hashes with the following structure:
#	DN	VO Member DN
#	CA	Certificate Authority that vouches for the member
#	CN	VO Member CN, extracted from DN
#	email	The email address of the user
sub listToHashes {
	my $cas_ref = shift;
	my @hashes;
	foreach $line (@_) {
		chomp($line);
		$csv->parse($line);
		my @components = $csv->fields();
		if ( scalar @components == 3 ) { #Crude way to filter out "No members..." messages
			my %mbr= ( 'DN' => "${components[0]}",'CA' => "${components[1]}", 'CN' => getCN($components[0]), 'email' => "${components[2]}" );
			push( @hashes, \%mbr );
		}
		else {
			if ( scalar @components > 3 ) { # Using slower algorithm to match members with commas in their subjects
				foreach $ca ( @$cas_ref ) {
					$pattern = qr/$ca/;
					if ( $line =~ /^(.*),${pattern},([^,]*)$/ ) {
						my %mbr= ( 'DN' => "$1",'CA' => "$ca", 'CN' => getCN($1), 'email' => "$2" );
						push( @hashes, \%mbr );
					}
				}
			}
		}
	}
	return \@hashes;
}


### effectCall runs actual voms-admin commands. It accepts three arguments:
#	$command	The shell command to run
#	$debugMsg	Message to log on execution
sub effectCall {
	$command = shift;
	$debugMsg = shift;

#	printf "$command\n\n";
	@out=`$command 2>&1`;

	if ( $? == 0 ) {
		syslog(LOG_INFO, "Done $debugMsg");
	}
	else {
		chomp(@out);
		syslog(LOG_ERR, "Failed $debugMsg Original message: @out");
		print STDERR "Failed $debugMsg\nOriginal message: @out\nOriginal command: $command\n";
		$retval = 1;
	}
}

### knownCA indicates whether a given CA is known to the VOMS server. It accepts the user structure
#	$cas_ref	Reference to an array of known CAs
#	$CA		The CA that should be checked CA
sub knownCA {
	$cas_ref = $_[0];
	$ca = $_[1];

	if(grep {$_ eq "$ca"} @$cas_ref) {
		return 1;
	} else {
		syslog LOG_ERR, "Unknown CA \"$user->{'CA'}\" requested with user \"$user->{'DN'}\"";
		print STDERR "Unknown CA \"$user->{'CA'}\" requested with user \"$user->{'DN'}\"\n";
		return 0;
	}
}


### readProperties reads VO properties file into an array
#	$path		Path to the file
sub readProperties {
	$path = shift;
	my %properties;
	if (open(INI, "$path")) {
		syslog LOG_DEBUG, "Reading config file \"$path\".";
		print STDERR "Reading config file \"$path\".\n";
		while (<INI>) {
			chomp;
			if (/^(\S*)\s*=\s*(\S*)(#.*)?$/) {
				$properties{"$1"} = "$2";
			}
		}
		close (INI);
	}
	else {
		syslog LOG_WARNING, "Could not open config file \"$path\". No way to read VO properties";
		print STDERR "Could not open config file \"$path\". No way to read VO properties\n";
	}
	return %properties;
}

### uniqueDN checks if the user's DN already exists in a list of DNs seen
#	$user_ref	User structure reference
#	$seen_ref	List of DNs for comparison
sub uniqueDN {
	$seen_ref = $_[1];
	$user_ref = $_[0];

	if(grep {$_ eq "$user_ref->{'DN'}"} @$seen_ref) {
		syslog LOG_ERR, "Duplicate user \"" . $user_ref->{'DN'} .
			"\" dropped with CA \"" . $user_ref->{'CA'} . "\"";
		print STDERR "Duplicate user \"" . $user_ref->{'DN'} .
			"\" dropped with CA \"" . $user_ref->{'CA'} . "\"\n";
		return 0;
	}
	return 1;
}

# This is the actual start.

openlog($program, 'cons,pid', 'user');
my $retval = 0;


# Main parsing loop for the input XML file
foreach my $vo (@{$vos->{'vo'}}) { # Iterating through individual VOs in the XML
	$name = $vo->{'name'};

	my %properties = readProperties("$etcDir/$name/$etcPropertyFilename");
	my $checkCA = $properties{"voms.skip_ca_check"} ne "True";
	syslog LOG_DEBUG, "voms.skip_ca_check: " . $properties{"voms.skip_ca_check"} . ", $checkCA\n";
	print STDERR "voms.skip_ca_check: " . $properties{"voms.skip_ca_check"} . ", $checkCA\n";

	#Collect lists from voms-admin
	my @groups_current=`voms-admin --vo \Q${name}\E list-groups`;
	if ( $? != 0 ) {
		syslog LOG_ERR, "Failed listing groups in VO \"$name\". Error Code $?, original message from voms-admin: @groups_current";
		print STDERR "Failed listing groups in VO \"$name\". Error Code $?, original message from voms-admin: @groups_current\n";
		$retval = 1;
		next;
	}
	chomp(@groups_current);
	s/^\s*// for @groups_current;

	my @roles_current=`voms-admin --vo \Q${name}\E list-roles`;
	if ( $? != 0 ) {
		syslog LOG_ERR, "Failed listing roles in VO \"$name\". Error Code $?, original message from voms-admin: @roles_current";
		print STDERR "Failed listing roles in VO \"$name\". Error Code $?, original message from voms-admin: @roles_current\n";
		$retval = 1;
		next;
	}
	chomp(@roles_current);
	s/^\s*Role=// for @roles_current;

	my @cas=`voms-admin --vo \Q${name}\E list-cas`;
	if ( $? != 0 ) {
		syslog LOG_ERR, "Failed listing known CAs for VO \"$name\". Error Code $?, original message from voms-admin: @cas";
		print STDERR "Failed listing known CAs for VO \"$name\". Error Code $?, original message from voms-admin: @cas\n";
		$retval = 1;
		next;
	}
	chomp(@cas);

	my @attributeClasses_current=`voms-admin --vo \Q${name}\E list-attribute-classes`;
	if ( $? != 0 ) {
		syslog LOG_ERR, "Failed listing attribute classes in VO \"$name\". Error Code $?, original message from voms-admin: @attributeClasses_current";
		print STDERR "Failed listing attribute classes in VO \"$name\". Error Code $?, original message from voms-admin: @attributeClasses_current\n";
		$retval = 1;
		next;
	}
	s/\s.*$// for @attributeClasses_current;
	chomp(@attributeClasses_current);

	#Collect current Group Membership and Role assignment
	my %groupRoles_current;		# Current assignment of users to (per group) roles
	my %groupMembers_current;	# Current membership in groups (pure, disregarding roles)
	foreach $group (@groups_current) {
		#Store members
		$groupMembers_current{"$group"}=listToHashes(\@cas, `voms-admin --vo \Q${name}\E list-members \Q${group}\E`);

		#Role Membership
		foreach $role (@roles_current) {
			$groupRoles_current{"$group"}{"$role"}=listToHashes(\@cas, `voms-admin --vo \Q${name}\E list-users-with-role \Q${group}\E \Q${role}\E`);
		}
	}

	$attributeStatusFile = $attributeStatusFilePrefix.$name.".xml";
	my @attributes_current;
	if ( -e $attributeStatusFile ) {
		my $attributes_read = XMLin( "$attributeStatusFile", ForceArray => [ 'attribute' ], KeyAttr => [], KeepRoot => 0 );
		foreach $attribute (@{$attributes_read->{'attribute'}}) {
				my %fixed = ( 'CA' => "$attribute->{'CA'}",'DN' => "$attribute->{'DN'}", 'name' => "$attribute->{'name'}", 'value' => "$attribute->{'value'}" );
			push (@attributes_current, \%fixed);
		}
		syslog LOG_INFO, "Reading attribute status for VO \"$name\" from file $attributeStatusFile";
	}
	else {
		syslog LOG_INFO, "No attribute status file exists for VO \"$name\" (looking for file $attributeStatusFile)";
	}

	# Produce comparable data structure from input data
	my %groupRoles_toBe;		# Desired assignment of users to (per group) roles
	my %groupMembers_toBe;		# Desired membership in groups (pure, disregarding roles)
	my @attributeClasses_toBe;	# Desired attribute classes
	my @attributes_toBe;		# List of al users with attributes
	my @groups_toBe = ( "/$name" );	# Desired list of groups
	my @roles_toBe = ( "VO-Admin" );# Desired list of roles, plus the default VO-Admin role
	my @DNs_Seen;			# DNs already included
	foreach $user (@{$vo->{'users'}->{'user'}}) {
		next unless knownCA(\@cas, $user->{'CA'});
		my %theUser= ( 'CA' => "$user->{'CA'}",'DN' => normalizeUID(normalizeEmail($user->{'DN'})), 'CN' => getCN($user->{'DN'}), 'email' => "$user->{'email'}" );
		next unless ($checkCA || uniqueDN(\%theUser, \@DNs_Seen));
		push(@DNs_Seen, $theUser{'DN'});
		if($user->{'nickname'}) {
			my %userAttributes = ( 'CA' => "$user->{'CA'}",'DN' => "$user->{'DN'}", 'name' => 'nickname', 'value' => "$user->{'nickname'}" );
			push(@attributes_toBe, \%userAttributes);
			push(@attributeClasses_toBe, 'nickname') unless grep{$_ == 'nickname'} @attributeClasses_toBe;
		}
		push( @{$groupMembers_toBe{"/$name"}}, \%theUser ); #Add user to root group (make them a member)
		foreach $group (@{$user->{'groups'}->{'group'}}){
			push(@groups_toBe, "/$name/$group->{'name'}") unless grep{$_ eq "/$name/$group->{'name'}"} @groups_toBe;
			push(@{$groupMembers_toBe{"/$name/$group->{'name'}"}}, \%theUser);
			foreach $role (@{$group->{'roles'}->{'role'}}) {
				push(@roles_toBe, "$role") unless grep{$_ eq "$role"} @roles_toBe;
				push(@{$groupRoles_toBe{"/$name/$group->{'name'}"}{"$role"}}, \%theUser);
			}
		}
		foreach $role (@{$user->{'roles'}->{'role'}}) { # Global roles
			push(@roles_toBe, "$role") unless grep{$_ eq "$role"} @roles_toBe;
			push(@{$groupRoles_toBe{"/$name"}{"$role"}}, \%theUser);
		}
	}


	# Make comparisons
	my @groupsToDelete = array_minus( @groups_current, @groups_toBe );
	my @groupsToCreate = array_minus( @groups_toBe, @groups_current );

	my @rolesToDelete = array_minus( @roles_current, @roles_toBe );
	my @rolesToCreate = array_minus( @roles_toBe, @roles_current );

	my @attributeClassesToDelete = array_minus( @attributeClasses_current, @attributeClasses_toBe );
	my @attributeClassesToCreate = array_minus( @attributeClasses_toBe, @attributeClasses_current );

	my @attributesToDelete = array_minus_deep( @attributes_current, @attributes_toBe );
	my @attributesToSet = array_minus_deep( @attributes_toBe, @attributes_current );

	my %membersToAdd;
	my %membersToAdd;
	my %rolesToAssign;
	my %rolesToDismiss;
	foreach $group (@groups_toBe) {
		@{$membersToRemove{"$group"}} = array_minus_deep(@{$groupMembers_current{"$group"}}, @{$groupMembers_toBe{"$group"}});
		@{$membersToRemove{"$group"}} = array_minus_deep(@{$membersToRemove{"$group"}}, @{$membersToRemove{"/$name"}}) unless( "$group" eq "/$name" ); # No need to remove user from groups if they are going to be fully removed
		@{$membersToAdd{"$group"}} = array_minus_deep(@{$groupMembers_toBe{"$group"}}, @{$groupMembers_current{"$group"}});
		foreach $role (@roles_toBe) {
			@{$rolesToAssign{"$group"}{"$role"}} = array_minus_deep(@{$groupRoles_toBe{"$group"}{"$role"}}, @{$groupRoles_current{"$group"}{"$role"}});
			@{$rolesToDismiss{"$group"}{"$role"}} = array_minus_deep(@{$groupRoles_current{"$group"}{"$role"}}, @{$groupRoles_toBe{"$group"}{"$role"}});
			@{$rolesToDismiss{"$group"}{"$role"}} = array_minus_deep(@{$rolesToDismiss{"$group"}{"$role"}}, @{$membersToRemove{"/$name"}}); # No need to revoke roles if the user is going to be fully removed
			@{$rolesToDismiss{"$group"}{"$role"}} = array_minus_deep(@{$rolesToDismiss{"$group"}{"$role"}}, @{$membersToRemove{"$group"}}); # No need to revoke roles if the user is going to be removed from the group
		}
	}


	# Effect changes
	# 1. create / delete groups
	foreach $group (@groupsToDelete) {
		effectCall "voms-admin --vo \Q$name\E delete-group \Q$group\E",
		"deleting Group \"$group\" from VO \"$name\"";
	}
	foreach $group (@groupsToCreate) {
		effectCall "voms-admin --vo \Q$name\E create-group \Q$group\E",
		"creating Group \"$group\" in VO \"$name\"";
	}

	# 2. create / delete roles
	foreach $role (@rolesToDelete) {
		effectCall "voms-admin --vo \Q$name\E delete-role \Q$role\E",
		"deleting Role \"$role\" from VO \"$name\".";
	}
	foreach $role (@rolesToCreate) {
		effectCall "voms-admin --vo \Q$name\E create-role \Q$role\E",
		"creating Role \"$role\" in VO \"$name\".";
	}

	# 2.5. create / delete attribute classes
	foreach $attributeClass (@attributeClassesToDelete) {
		effectCall "voms-admin --vo \Q$name\E delete-attribute-class \Q$attributeClass\E",
		"deleting Attribute Class \"$attributeClass\" from VO \"$name\".";
	}

	foreach $attributeClass (@attributeClassesToCreate) {
		effectCall "voms-admin --vo \Q$name\E create-attribute-class \Q$attributeClass\E \Q$attributeClass\E false",
		"creating Attribute Class \"$attributeClass\" in VO \"$name\".";
	}

	# 3. add members to/remove members from groups
	foreach $group (@groups_toBe) {
		foreach $user (@{$membersToRemove{"$group"}}) {
			if( "$group" eq "/$name" ) { # Root group?
				effectCall "voms-admin --nousercert --vo \Q$name\E delete-user \Q$user->{'DN'}\E \Q$user->{'CA'}\E",
				"deleting user \"$user->{'DN'}\" from VO \"$name\".";
			}
			else {
				effectCall "voms-admin --nousercert --vo \Q$name\E remove-member \Q$group\E \Q$user->{'DN'}\E \Q$user->{'CA'}\E",
				"removing user \"$user->{'DN'}\" from Group \"$group\" in VO \"$name\".";
			}
		}
		foreach $user (@{$membersToAdd{"$group"}}) {
			if( "$group" eq "/$name" ) { # Root group?
				effectCall "voms-admin --nousercert --vo \Q$name\E create-user \Q$user->{'DN'}\E \Q$user->{'CA'}\E \Q$user->{'CN'}\E \Q$user->{'email'}\E",
				"creating user \"$user->{'DN'}\" in VO \"$name\".";
			}
			else {
				effectCall "voms-admin --nousercert --vo \Q$name\E add-member \Q$group\E \Q$user->{'DN'}\E \Q$user->{'CA'}\E",
				"adding user \"$user->{'DN'}\" to Group \"$group\" in VO \"$name\".";
			}
		}
	}

	# 4. assign/dismiss roles
	foreach $group (@groups_toBe) {
		foreach $role (@roles_toBe) {
			foreach $user (@{$rolesToDismiss{"$group"}{"$role"}}) {
				effectCall "voms-admin --nousercert --vo \Q$name\E dismiss-role \Q$group\E \Q$role\E \Q$user->{'DN'}\E \Q$user->{'CA'}\E",
				"stripping user \"$user->{'DN'}\" of Role \"$role\" for Group \"$group\" in VO \"$name\"";
			}
			foreach $user (@{$rolesToAssign{"$group"}{"$role"}}) {
				effectCall "voms-admin --nousercert --vo \Q$name\E assign-role \Q$group\E \Q$role\E \Q$user->{'DN'}\E \Q$user->{'CA'}\E",
				"assigning Role \"$role\" to user \"$user->{'DN'}\" for Group \"$group\" in VO \"$name\"";
			}
		}
	}

	# 5. Set attribute values
	# first delete unwanted
	my @attributes_deleted;
	foreach $attribute (@attributesToDelete) {
		push (@attributes_deleted, $attribute) if effectCall "voms-admin --nousercert --vo \Q$name\E delete-user-attribute \Q$attribute->{'DN'}\E \Q$attribute->{'CA'}\E \Q$attribute->{'name'}\E",
		"deleting Attribute \"$attribute->{'name'}\" for user \"$attribute->{'DN'}\" in VO \"$name\"";
	}
	# then set new ones
	foreach $attribute (@attributesToSet) {
		push (@attributes_current, $attribute) if effectCall "voms-admin --nousercert --vo \Q$name\E set-user-attribute \Q$attribute->{'DN'}\E \Q$attribute->{'CA'}\E \Q$attribute->{'name'}\E \Q$attribute->{'value'}\E",
		"setting Attribute \"$attribute->{'name'}\" to value \"$attribute->{'value'}\" for user \"$attribute->{'DN'}\" in VO \"$name\"";

	}

	my @attributes_existing = array_minus_deep( @attributes_current, @attributes_deleted );
	if( open( my $of, ">", "$attributeStatusFile" ) ) {
		my $xml = {attributes => {attribute => \@attributes_existing} };
		XMLout($xml, KeepRoot => 1, NoAttr => 1,  OutputFile => $of );
		close( $of );
	}
	else {
		syslog LOG_ERR, "Failed storing attribute status for VO \"$name\" in file $attributeStatusFile";
		print STDERR "Failed storing attribute status for VO \"$name\" in file $attributeStatusFile\n";
	}
}

closelog();

exit $retval;
