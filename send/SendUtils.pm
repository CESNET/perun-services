package SendUtils;
use strict;
use warnings FATAL => 'all';
use Fcntl qw(:flock);

# How to call?
# BEGIN {push @INC, '/dir/for/perl/lib'}
# use SendUtils;
# SendUtils::lock_file("Name");
# SendUtils::unlock_file($lock);

#
# Create a lock file of specified name and keeps it locked
# until unlock_file is called. This prevents concurrent run
# of send scripts.
#
# In case of process/system failiure lock file is unlocked by the OS.
#
sub lock_file {

	my $lock;

	my ($lockDirName) = @_;
	unless(defined($lockDirName)) { die "Missing log dir name - $!\n"; }

	my $lockMainDir = "lock";
	my $lockDir = $lockMainDir . "/" . $lockDirName . ".lock";
	my $lockPidFile = $lockDir . "/pid";
	unless(-d $lockDir) { mkdir $lockDir or die "Cannot create $lockDir - $!\n"; }

	open($lock, ">", $lockPidFile) or die "Can't open lock file: $!";
	flock($lock, LOCK_EX|LOCK_NB) or die "Cannot create a lock, probably already locked - $!\n";
	print $lock $$;

	return $lock;

}

#
# Unlock the lock file created by the call lock_file
#
sub unlock_file {
	my ($lock) = @_;
	unless(defined($lock)) { die "Can't unlock file, lock was not created!"; }
	flock($lock, LOCK_UN|LOCK_NB) or die "Cannot unlock file - $!\n";
}

1;