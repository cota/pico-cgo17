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
my $tool = 'bin/x86_64-baseline-user';
my $test = 'bin/x86_64-atomic_add';
my $threads = '4,8';
my $duration = 4;
my $range = 64;

my $name = 'cas.pl';
my $usage = "$name [options]\n" .
    "Options:\n" .
    " --duration: duration in seconds. Default: $duration\n" .
    " --range: range of elements (will be rounded up to a power of two). Default: $range\n" .
    " --threads: comma-separated numbers of threads. Default: $threads\n" .
    " --tool: binary to run the workload with. Default: $tool\n" .
    " --tries: number of tries per test. Default: $tries\n" .
    "Note: results are printed to standard error; atomic_add messages are printed to standard output.\n" .
    "\n" .
    "Example:\n" .
    "./$name --duration=2 --range=32 --tool=$tool --tries=3 --threads=1,2,4 2>cas-out.dat\n" .
    "    Runs the x86_64 atomic_add benchmark with 32 elements for 1,2 and 4 threads. Each run takes\n" .
    "    2 seconds, and results are averaged from 3 runs. The emulator binary used\n" .
    "    is $tool. Results are saved to cas-out.dat in gnuplot format.\n";

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

my $bind_path = 'cputopology-perl/list.pl';

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
