#!/usr/bin/perl

use warnings;
use strict;
use Cwd;

use Time::HiRes qw(gettimeofday tv_interval);

BEGIN {push @INC, '..'}
use Mean;

use Getopt::Long;
use Data::Dumper;

my $tries = 1;
my $help;
my $tool = 'bin/aarch64-baseline';
my $test = 'bin/atomic_add-bench-aarch64';
my $threads = '4,8';
my $duration = 4;
my $range = 64;

my $usage = "st.pl [options]\n" .
    "Options:\n" .
    " --duration: duration in seconds. Default: $duration\n" .
    " --range: range of elements (will be rounded up to a power of two). Default: $range\n" .
    " --threads: comma-separated numbers of threads. Default: $threads\n" .
    " --tool: binary to run the workload with. Default: $tool\n" .
    " --tries: number of tries per test. Default: $tries\n" .
   "Note: results are printed to standard error; atomic_add messages are printed to standard output.\n";

GetOptions (
    'duration=i' => \$duration,
    'h|help' => \$help,
    'range=i' => \$range,
    'threads=s' => \$threads,
    'tool=s' => \$tool,
    'tries=i' => \$tries,
    );

if (defined($help)) {
    print $usage;
    exit 0;
}

my @threads = split(',', $threads);

if ($tool !~ /^\//) {
    my $cwd = getcwd;
    $tool = "$cwd/$tool";
}
if (! -e $tool) {
    die "$tool does not exist";
}

my $bind_path = '../cputopology-perl/list.pl';

foreach my $th (@threads) {
    my @res = ();
    for (my $i = 0; $i < $tries; $i++) {
	my $bind = `$bind_path --policy=compact $th`;
	chomp($bind);
	my $cmd = "taskset -c $bind ";
	$cmd .= "$tool $test -n $th -d $duration -r $range";

	print "$cmd\n";
	my $fh;
	my $pid = open($fh, "$cmd 2>&1 | ") or die "cannot open: $?";
	my $throughput;
	while (my $line = <$fh>) {
	    print $line;
	    if ($line =~ /\s*Throughput:\s+([0-9.]+) Mops/) {
		$throughput = $1;
	    }
	}
	close $fh;
	die if (!defined($throughput));
	push @res, $throughput;
    }
    print STDERR join("\t", $th, Mean::arithmetic(\@res), Mean::stdev(\@res)), "\n";
}

sub sys {
    my $cmd = shift(@_);
    system("$cmd") == 0 or die "cannot run '$cmd': $?";
}
