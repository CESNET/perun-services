package VsupIfis;
use Exporter 'import';
@ISA = ('Exporter');
@EXPORT = qw(load_kos load_dc2);

use strict;
use warnings FATAL => 'all';
use DBI;

#
# Return config
# Requires param "filename" with config
#
sub init_config($) {

	my $filename = shift;
	my $configPath = "/home/perun/perun-sync/$filename";
	my $result = {};

	open FILE, $configPath or die "Could not open config file $configPath: $!";
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
# Load map of users relations from KOS
# Require params: $hostname, $port, $db_name, $db_user, $db_password
#
sub load_kos() {

	my $config = init_config("kos.conf");

	my $hostname = $config->{"hostname"};
	my $port = $config->{"port"};
	my $db_name = $config->{"db_name"};
	my $db_user = $config->{"username"};
	my $db_password = $config->{"password"};

	my $dbh = DBI->connect("dbi:Oracle://$hostname:$port/$db_name", $db_user, $db_password,{ RaiseError=>1, AutoCommit=>0, LongReadLen=>65536, ora_charset => 'AL32UTF8'}) or die "Connect to database $db_name Error!\n";
	$dbh->do("alter session set nls_date_format='YYYY-MM-DD HH24:MI:SS'");

	# Select query for input database (KOS) - all students with UCO not null and DO_ >= now or null
	my $sth = $dbh->prepare(qq{select case when OSB_ID=UCO then null else UCO end as UCO, NS, 'STU' as TYP_VZTAHU, STUD_FORMA as DRUH_VZTAHU, ID_STUDIA as VZTAH_CISLO, STUD_FORMA as STU_FORMA, STUD_STAV as STUD_STAV, STUD_TYP as STU_PROGR, OD, DO_, KARTA_LIC as KARTA_IDENT from SIS2IDM_STUDIA where (case when OSB_ID=UCO then null else UCO end) is not null and (DO_ >= SYSDATE OR DO_ is NULL)});
	$sth->execute();

	# Structure to store data from input database (KOS)
	my $inputData = {};
	while(my $row = $sth->fetchrow_hashref()) {
		my $key = $row->{VZTAH_CISLO};
		$inputData->{$key}->{'OSB_ID'} = $row->{UCO};
		$inputData->{$key}->{'TYP_VZTAHU'} = $row->{TYP_VZTAHU};
		$inputData->{$key}->{'DRUH_VZTAHU'} = $row->{DRUH_VZTAHU};
		$inputData->{$key}->{'STU_FORMA'} = $row->{STU_FORMA};
		$inputData->{$key}->{'STUD_STAV'} = $row->{STUD_STAV};
		$inputData->{$key}->{'STU_PROGR'} = $row->{STU_PROGR};
		$inputData->{$key}->{'NS'} = $row->{NS};
		$inputData->{$key}->{'VZTAH_OD'} = $row->{OD};
		$inputData->{$key}->{'VZTAH_DO'} = $row->{DO_};
		$inputData->{$key}->{'KARTA_IDENT'} = $row->{KARTA_IDENT};
	}

	# Disconnect from input database (KOS)
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
	my $sth = $dbh->prepare(qq{SELECT UCO, VZTAH_CISLO, NS, VZTAH_STATUS_NAZEV, OD, DO,
	CASE WHEN (VZTAH_STATUS_CISLO in (1,2,4,5,7,8,9,10,16,17,21) AND VZTAH_FUNKCE_CISLO in (1,2,3,4,5,52))
		THEN 'ITIC'
	ELSE null
	END as KARTA_IDENT,
	VZTAH_STATUS_CISLO
	FROM PAM2IDM_VZTAHY
	WHERE (DO >= SYSDATE OR DO is NULL)});
	$sth->execute();

	# Structure to store data from input database (DC2)
	my $inputData = {};
	while(my $row = $sth->fetchrow_hashref()) {
		my $key = $row->{VZTAH_CISLO};
		$inputData->{$key}->{'OSB_ID'} = $row->{UCO};
		$inputData->{$key}->{'VZTAH_STATUS_NAZEV'} = $row->{VZTAH_STATUS_NAZEV};
		$inputData->{$key}->{'NS'} = $row->{NS};
		$inputData->{$key}->{'VZTAH_OD'} = $row->{OD};
		$inputData->{$key}->{'VZTAH_DO'} = $row->{DO};
		$inputData->{$key}->{'KARTA_IDENT'} = $row->{KARTA_IDENT};
		$inputData->{$key}->{'VZTAH_STATUS_CISLO'} = $row->{VZTAH_STATUS_CISLO};
	}

	# Disconnect from input database (KOS)
	$dbh->disconnect();

	return $inputData;

}

1;
