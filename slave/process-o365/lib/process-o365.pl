#!/usr/bin/perl

use LWP::UserAgent;
use MIME::Base64;
use JSON;

my $licenses = {};
my $photos = {};

# o365
my @listOfUsersActual;
my $o365UserMapper = {};

# Perun
my @listOfUsersPerun;
my $perunUsersMapper = {};
my $filenameUsersPerun = '${WORK_DIR}/$FILE_USERS';
my $filenamePhotosPerun = '${WORK_DIR}/$FILE_PHOTOS';

# call API endpoint to obtain all licenses and load them into $licenses structure
my $ua = LWP::UserAgent->new;
my $server_endpoint = "https://graph.microsoft.com/v1.0/subscribedSkus";

my $headers = HTTP::Headers->new;
$headers->content_type("application/json");
$headers->authorization('$ACCESS_TOKEN');

my $req = HTTP::Request->new('GET', $server_endpoint, $headers);
my $resp = $ua->request($req);
if ($resp->is_success) {
	my $lineLicenses = $resp->decoded_content;

	while($lineLicenses =~ /"skuId"\s*:\s*"([^"]*)","skuPartNumber"\s*:\s*"([^"]*)"/g) {
		$licenses->{$2} = $1;
	}
} else {
	die $resp->status_line;
}

# call API endpoint to obtain users from o365 and load them into @listOfUsersActual array
$server_endpoint = "https://graph.microsoft.com/v1.0/users";
$req = HTTP::Request->new('GET', $server_endpoint, $headers);

$resp = $ua->request($req);
if ($resp->is_success) {
	my $content = $resp->decoded_content;
	@listOfUsersActual = @{JSON::XS->new->utf8->decode ($content)->{value}};

	# change accountEnabled from integer to boolean
	foreach my $member (@listOfUsersActual) {
		$member->{accountEnabled} = ( $member->{accountEnabled} ? 'true' : 'false' );
	}
} else {
	die $resp->status_line;
}

# obtain users from Perun and load them into listOfUsersPerun structure
open FILE_USERS_PERUN, "<", "$filenameUsersPerun" or die "Cant open '$filenameUsersPerun': $!";
while (my $lineUsersPerun = <FILE_USERS_PERUN>) {
	chomp $lineUsersPerun;
	@listOfUsersPerun = @{JSON::XS->new->utf8->decode ($lineUsersPerun)->{value}};

	# change accountEnabled from integer to boolean
	foreach my $member (@listOfUsersPerun) {
		$member->{accountEnabled} = ( $member->{accountEnabled} ? 'true' : 'false' );
	}
}
close FILE_USERS_PERUN;

# obtain user photos from Perun
open FILE_PHOTOS_PERUN, "<", "$filenamePhotosPerun" or die "Cant open '$filenamePhotosPerun': $!";
while (my $lineUserPhotoPerun = <FILE_PHOTOS_PERUN>) {
	chomp $lineUserPhotoPerun;
	my @line = split(/,/, $lineUserPhotoPerun);

	$photos->{$line[0]} = $line[1];
}
close FILE_PHOTOS_PERUN;

foreach my $userPerun (@listOfUsersPerun) {
	# store all userPrincipalNames to separated arrays for quick check at the end of the script
	my $userPrincipalNamePerun = $userPerun->{userPrincipalName};
	$perunUsersMapper->{$userPrincipalNamePerun} = 1;

	foreach my $userActual (@listOfUsersActual) {
		# store all userPrincipalNames to separated arrays for quick check at the end of the script
		my $userPrincipalName = $userActual->{userPrincipalName};
		$o365UserMapper->{$userPrincipalName} = 1;

		if ($userPrincipalName eq $userPrincipalNamePerun) {
			my $updateLicenses = {};
			my $skuIdUserPerun = {};
			my $skuIdUserActual = {};

			# parse only license skuId from structures
			foreach my $userPerunLicense (@{$userPerun->{assignedLicenses}}) {
				my $skuIdLicensePerun = $licenses->{$userPerunLicense};
				$skuIdUserPerun->{$skuIdLicensePerun} = 1;
				foreach my $userActualLicense (@{$userActual->{assignedLicenses}}) {
					my $skuIdLicense = $userActualLicense->{skuId};
					$skuIdUserActual->{$skuIdLicense} = 1;
				}
			}

			# compare licenses and delete those, who are present in both hashes
			foreach my $skuIdPerun (keys %{$skuIdUserPerun}) {
				foreach my $skuIdActual (keys %{$skuIdUserActual}) {
					if($skuIdPerun eq $skuIdActual) {
						delete $skuIdUserPerun->{$skuIdPerun};
						delete $skuIdUserActual->{$skuIdActual};
					}
				}
			}

			# add licenses to o365
			if($skuIdUserPerun) {
				my @newLicenses;
				foreach my $userPerunLicense (keys %{$skuIdUserPerun}) {
					my $newLicense = {};
					my @plans;
					$newLicense->{disabledPlans} = \@plans;
					$newLicense->{skuId} = $userPerunLicense;
					push @newLicenses, $newLicense;
				}
				$updateLicenses->{'addLicenses'} = \@newLicenses;
			}

			# remove licenses from o365
			if($skuIdUserActual) {
				my @oldLicenses;
				foreach my $userLicense (keys %{$skuIdUserActual}) {
					push @oldLicenses, $userLicense;
				}
				$updateLicenses->{'removeLicenses'} = \@oldLicenses;
			}

			# update user assigned licenses, if they are not equal
			if ($updateLicenses->{addLicenses} || $updateLicenses->{removeLicenses}) {
				# call API endpoint for user licenses update
				$server_endpoint = "https://graph.microsoft.com/v1.0/users/$userPrincipalName/assignLicense";

				$req = HTTP::Request->new('POST', $server_endpoint, $headers, JSON::XS->new->utf8->encode->($updateLicenses));

				$resp = $ua->request($req);
				if ($resp->is_error) {
					die $resp->status_line;
				}
			}

			# update user fields if they are not equal
			if ($userPerun->{accountEnabled} ne $userActual->{accountEnabled} || $userPerun->{displayName} ne $userActual->{displayName} ||
				$userPerun->{givenName} ne $userActual->{givenName} || $userPerun->{mail} ne $userActual->{mail} ||
				$userPerun->{surname} ne $userActual->{surname} || $userPerun->{usageLocation} ne $userActual->{usageLocation} ||
				$userPerun->{userPrincipalName} ne $userActual->{userPrincipalName} || $userPerun->{userType} ne $userActual->{userType}) {

				# prepare json
				delete $userPerun->{assignedLicenses};

				# call API endpoint for user update
				$server_endpoint = "https://graph.microsoft.com/v1.0/users/$userPrincipalName";
				$req = HTTP::Request->new('PATCH', $server_endpoint, $headers, JSON::XS->new->utf8->encode->($userPerun));

				$resp = $ua->request($req);
				if ($resp->is_error) {
					die $resp->status_line;
				}
			}

			my $photoBase64Perun = $photos->{$userPrincipalName};
			if ($photoBase64Perun) {
				# call API to get user photo
				$server_endpoint = "https://graph.microsoft.com/v1.0/users/$userPrincipalName/photo";
				$headers->content_type("image/jpeg");
				$req = HTTP::Request->new('GET', $server_endpoint, $headers);

				$resp = $ua->request($req);
				if ($resp->is_success) {
					my $photo = encode_base64($resp->decoded_content);

					if ($photo && $photo ne $photoBase64Perun) {
						# call API endpoint for photo update
						$server_endpoint = "https://graph.microsoft.com/v1.0/users/$userPrincipalName/photo/\$value";
						$headers->content_type("image/jpeg");
						$req = HTTP::Request->new('PUT', $server_endpoint, $headers, decode_base64(photoBase64Perun));

						$resp = $ua->request($req);
						if ($resp->is_error) {
							die $resp->status_line;
						}
					}
				}
			}
		}
	}
}

# compare users and delete those, who are present in both hashes
foreach my $userPerun (keys %{$perunUsersMapper}) {
	foreach my $userActual (keys %{$o365UserMapper}) {
		if($userPerun eq $userActual) {
			delete $perunUsersMapper->{$userPerun};
			delete $o365UserMapper->{$userActual};
		}
	}
}

# when o365 returns user, who is not returned from Perun system, change its status to disabled
foreach my $userActual (@listOfUsersActual) {
	my $userPrincipalName = $userActual->{'userPrincipalName'};
	if($o365UserMapper->{$userPrincipalName}) {
		$userActual->{'accountEnabled'} = 'false';
		delete $userActual->{assignedLicenses};

		# call API endpoint for user update
		$server_endpoint = "https://graph.microsoft.com/v1.0/users/$o365UserMapper->{$userPrincipalName}";
		$headers->content_type("application/json");
		$req = HTTP::Request->new('PATCH', $server_endpoint, $headers, JSON::XS->new->utf8->encode->($userActual));

		$resp = $ua->request($req);
		if ($resp->is_error) {
			die $resp->status_line;
		}
	}
}

# when Perun returns user, who is not returned by o365, report error
my @missingUsers;
foreach my $userPerun (@listOfUsersPerun) {
	my $userPrincipalName = $userPerun->{'userPrincipalName'};
	if($perunUsersMapper->{$userPrincipalName}) {
		push @missingUsers, $userPrincipalName;
	}
}
if (@missingUsers) {
	die "O365 should contain these users: @missingUsers \n";
}
