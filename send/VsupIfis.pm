package VsupIfis;
use Exporter 'import';
@ISA = ('Exporter');
@EXPORT = qw(load_dc2 load_stag);

use strict;
use warnings FATAL => 'all';
use DBI;
use utf8;
use open qw/ :std :encoding(utf8) /;
binmode STDOUT, ":utf8";

#
# Return config
# Requires param "filename" with config
#
sub init_config($) {

	my $filename = shift;
	my $configPath = "/etc/perun/services/vsup_ifis/$filename";
	my $result = {};

	open FILE, $configPath or die "Could not open config file $configPath: $!";
	binmode FILE, ":utf8";
	while(my $line = <FILE>) {
		if($line =~ /^username: .*/) {
			my $username = ($line =~ m/^username: (.*)$/)[0];
			$result->{"username"} = $username;
		} elsif($line =~ /^password: .*/) {
			my $password = ($line =~ m/^password: (.*)$/)[0];
			$result->{"password"} = $password;
		} elsif($line =~ /^hostname: .*/) {
			my $hostname = ($line =~ m/^hostname: (.*)$/)[0];
			$result->{"hostname"} = $hostname;
		} elsif($line =~ /^port: .*/) {
			my $port = ($line =~ m/^port: (.*)$/)[0];
			$result->{"port"} = $port;
		} elsif($line =~ /^db_name: .*/) {
			my $db_name = ($line =~ m/^db_name: (.*)$/)[0];
			$result->{"db_name"} = $db_name;
		}
	}

	return $result;

}

#
# Load map of users relations from IS/STAG
# Require params: $hostname, $port, $db_name, $db_user, $db_password
#
sub load_stag() {

	my $config = init_config("stag.conf");

	my $hostname = $config->{"hostname"};
	my $port = $config->{"port"};
	my $db_name = $config->{"db_name"};
	my $db_user = $config->{"username"};
	my $db_password = $config->{"password"};

	my $dbh = DBI->connect("dbi:Oracle://$hostname:$port/$db_name", $db_user, $db_password,{ RaiseError=>1, AutoCommit=>0, LongReadLen=>65536, ora_charset => 'AL32UTF8'}) or die "Connect to database $db_name Error!\n";
	$dbh->do("alter session set nls_date_format='YYYY-MM-DD HH24:MI:SS'");

	# Select query for input database (IS/STAG) - all students with UCO_PERUN not null and STUD_DO >= now-28 or null
	my $sth = $dbh->prepare(qq{select distinct STUDENT_STUDIUM.UCO_PERUN as UCO, NS, 'STU' as TYP_VZTAHU, STUD_FORMA as DRUH_VZTAHU, STUDENT_STUDIUM.ID_STUDIA as VZTAH_CISLO, STUD_FORMA as STU_FORMA, STUD_STAV as STU_STAV, STUD_TYP as STU_PROGR, STUD_OD, case when STUD_DO is not null then STUD_DO+28 ELSE STUD_DO END as STUD_DO, KARTA_LIC as KARTA_IDENT, UKONCENO as STU_GRADUATE from STUDENT_STUDIUM left join STUDENT_ADRESY on STUDENT_STUDIUM.ID_STUDIA=STUDENT_ADRESY.ID_STUDIA where STUDENT_STUDIUM.UCO_PERUN is not null and (STUD_DO >= TRUNC(SYSDATE)-28 OR STUD_DO is NULL)});
	$sth->execute();

	# Structure to store data from input database (IS/STAG)
	my $inputData = {};
	while(my $row = $sth->fetchrow_hashref()) {
		my $key = $row->{VZTAH_CISLO};
		$inputData->{$key}->{'OSB_ID'} = $row->{UCO};
		$inputData->{$key}->{'TYP_VZTAHU'} = $row->{TYP_VZTAHU};
		$inputData->{$key}->{'DRUH_VZTAHU'} = $row->{DRUH_VZTAHU};
		$inputData->{$key}->{'STU_FORMA'} = $row->{STU_FORMA};
		$inputData->{$key}->{'STU_STAV'} = $row->{STU_STAV};
		$inputData->{$key}->{'STU_PROGR'} = $row->{STU_PROGR};
		$inputData->{$key}->{'STU_GRADUATE'} = $row->{STU_GRADUATE};
		$inputData->{$key}->{'NS'} = $row->{NS};
		$inputData->{$key}->{'VZTAH_OD'} = $row->{STUD_OD};
		$inputData->{$key}->{'VZTAH_DO'} = $row->{STUD_DO};
		$inputData->{$key}->{'KARTA_IDENT'} = $row->{KARTA_IDENT};
	}

	# Disconnect from input database (IS/STAG)
	$dbh->disconnect();

	return $inputData;

}

#
# Load map of users relations from DC2
#
sub load_dc2() {

	my $config = init_config("dc2.conf");

	my $hostname = $config->{"hostname"};
	my $port = $config->{"port"};
	my $db_name = $config->{"db_name"};
	my $db_user = $config->{"username"};
	my $db_password = $config->{"password"};

	my $dbh = DBI->connect("dbi:Oracle://$hostname:$port/$db_name", $db_user, $db_password,{ RaiseError=>1, AutoCommit=>0, LongReadLen=>65536, ora_charset => 'AL32UTF8'}) or die "Connect to database $db_name Error!\n";
	$dbh->do("alter session set nls_date_format='YYYY-MM-DD HH24:MI:SS'");

	# Select query for input database (DC2) - internal/external teachers with valid relation
	my $sth = $dbh->prepare(qq{SELECT UCO, VZTAH_CISLO, NS, VZTAH_STATUS_NAZEV, VZTAH_STATUS_CISLO, OD, DO,
        CASE WHEN (VZTAH_STATUS_CISLO in (1,2,4,5,6,7,8,9,10,16,17,18,21) AND VZTAH_FUNKCE_CISLO in (1,2,3,4,5,7,52,58,79))
                THEN 'ITIC'
        ELSE null
        END as KARTA_IDENT
        FROM PAM2IDM_VZTAHY
        WHERE (DO >= TRUNC(SYSDATE) OR DO is NULL) and UCO is not null});
	$sth->execute();

	#Structure to store data from input database (DC2)
	my $inputData = {};
	while(my $row = $sth->fetchrow_hashref()) {
		my $key = $row->{VZTAH_CISLO};
		$inputData->{$key}->{'OSB_ID'} = $row->{UCO};
		# Limit to 35 ??? ($row->{VZTAH_STATUS_NAZEV}) ? substr($row->{VZTAH_STATUS_NAZEV}, 0, 35) : undef;
		$inputData->{$key}->{'VZTAH_STATUS_NAZEV'} = $row->{VZTAH_STATUS_NAZEV};
		$inputData->{$key}->{'NS'} = $row->{NS};
		$inputData->{$key}->{'VZTAH_OD'} = $row->{OD};
		$inputData->{$key}->{'VZTAH_DO'} = $row->{DO};
		$inputData->{$key}->{'KARTA_IDENT'} = $row->{KARTA_IDENT};
		$inputData->{$key}->{'VZTAH_STATUS_CISLO'} = $row->{VZTAH_STATUS_CISLO};
	}

	# Disconnect from input database (DC2)
	$dbh->disconnect();

	return $inputData;

}

1;
