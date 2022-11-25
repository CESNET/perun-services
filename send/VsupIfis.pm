package VsupIfis;
use Exporter 'import';
@ISA = ('Exporter');
@EXPORT = qw(load_kos load_vema load_dc2 load_is);

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
# Load map of users relations from IS
# Require params: $hostname, $port, $db_name, $db_user, $db_password
#
sub load_is() {

	my $config = init_config("is.conf");

	my $hostname = $config->{"hostname"};
	my $port = $config->{"port"};
	my $db_name = $config->{"db_name"};
	my $db_user = $config->{"username"};
	my $db_password = $config->{"password"};

	my $dbh = DBI->connect("dbi:Pg:dbname=$db_name;host=$hostname;port=$port", $db_user, $db_password,{ RaiseError=>1, AutoCommit=>0 }) or die "Connect to database $db_name Error!\n";

	# Select query for input database (IS) - all students with UCO_PERUN not null and STUD_DO >= now or null
	my $sth = $dbh->prepare(qq{select distinct ex_is2idm_studia.UCO_PERUN as UCO, NS, 'STU' as TYP_VZTAHU, STUD_FORMA as DRUH_VZTAHU, ex_is2idm_studia.ID_STUDIA as VZTAH_CISLO, STUD_FORMA as STU_FORMA, STUD_STAV as STUD_STAV, STUD_TYP as STU_PROGR, STUD_OD, STUD_DO, KARTA_LIC as KARTA_IDENT from ex_is2idm_studia left join ex_is2idm_adresy on ex_is2idm_studia.ID_STUDIA=ex_is2idm_adresy.ID_STUDIA where ex_is2idm_studia.UCO_PERUN is not null and (STUD_DO >= CURRENT_DATE OR STUD_DO is NULL)});
	$sth->execute();

	# Structure to store data from input database (IS)
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
		$inputData->{$key}->{'VZTAH_OD'} = $row->{STUD_OD};
		$inputData->{$key}->{'VZTAH_DO'} = $row->{STUD_DO};
		$inputData->{$key}->{'KARTA_IDENT'} = $row->{KARTA_IDENT};
	}

	# Disconnect from input database (IS)
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
        CASE WHEN (VZTAH_STATUS_CISLO in (1,2,4,5,6,7,8,9,10,16,17,18,21) AND VZTAH_FUNKCE_CISLO in (1,2,3,4,5,52))
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
	my $sth = $dbh->prepare(qq{select case when OSB_ID=UCO then null else UCO end as UCO, NS, 'STU' as TYP_VZTAHU, STUD_FORMA as DRUH_VZTAHU, ID_STUDIA as VZTAH_CISLO, STUD_FORMA as STU_FORMA, STUD_STAV as STUD_STAV, STUD_TYP as STU_PROGR, OD, DO_, KARTA_LIC as KARTA_IDENT from SIS2IDM_STUDIA where (case when OSB_ID=UCO then null else UCO end) is not null and (DO_ >= TRUNC(SYSDATE) OR DO_ is NULL)});
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
# Load map of users relations from VEMA
#
sub load_vema() {

	my $config = init_config("vema.conf");

	my $hostname = $config->{"hostname"};
	my $port = $config->{"port"};
	my $db_name = $config->{"db_name"};
	my $db_user = $config->{"username"};
	my $db_password = $config->{"password"};

	my $dbh = DBI->connect("dbi:Oracle://$hostname:$port/$db_name", $db_user, $db_password,{ RaiseError=>1, AutoCommit=>0, LongReadLen=>65536, ora_charset => 'AL32UTF8'}) or die "Connect to database $db_name Error!\n";
	$dbh->do("alter session set nls_date_format='YYYY-MM-DD HH24:MI:SS'");

	# Select query for input database (VEMA) - internal/external teachers with valid relation
	my $sth = $dbh->prepare(qq{SELECT UCO, VZ_CISLO, NS, VZ_S_N, OD, DO_,
	CASE WHEN (VZ_S_C in (101) AND VZ_F_C in (1,2,3,4,5,52))
		THEN 'ITIC'
	ELSE null
	END as KARTA_IDENT,
	VZ_S_C
	FROM PAMIDMVZ
	WHERE (DO_ >= TRUNC(SYSDATE) OR DO_ is NULL) and UCO is not null});
	$sth->execute();

	# Structure to store data from input database (VEMA)
	my $inputData = {};
	while(my $row = $sth->fetchrow_hashref()) {
		my $key = $row->{UCO} . "_" . $row->{VZ_CISLO};
		$inputData->{$key}->{'OSB_ID'} = $row->{UCO};
		$inputData->{$key}->{'VZ_CISLO'} = $row->{VZ_CISLO};
		$inputData->{$key}->{'VZTAH_STATUS_NAZEV'} = ($row->{VZ_S_N}) ? substr($row->{VZ_S_N}, 0, 35) : undef;
		$inputData->{$key}->{'NS'} = $row->{NS};
		$inputData->{$key}->{'VZTAH_OD'} = $row->{OD};
		$inputData->{$key}->{'VZTAH_DO'} = $row->{DO_};
		$inputData->{$key}->{'KARTA_IDENT'} = $row->{KARTA_IDENT};
		$inputData->{$key}->{'VZTAH_STATUS_CISLO'} = $row->{VZ_S_C};
	}

	# Disconnect from input database (VEMA)
	$dbh->disconnect();

	return $inputData;

}

1;
