#!/usr/bin/perl -w

use strict;

use IO::Handle;

my $io = new IO::Handle;

open my $in, $ARGV[0] || die "Cannot open $ARGV[0]";

$io->fdopen($in, 'w');
$io->sync() || die "Cannot sync $ARGV[0]";
$io->close();

close $in;

exit 0;
