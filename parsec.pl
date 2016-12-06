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
my $size = 'native';
my $tool = '/usr/bin/time';
my $test = 'blackscholes';
my $threads = '4,8';

my $name = 'parsec.pl';
my $usage = "$name [options]\n" .
    "Options:\n" .
    " --benchmark: name of the PARSEC benchmark to run. Default: $test\n" .
    " --size:  test, simdev, simsmall, simmedium, simlarge, native. Default: $size\n" .
    " --tool: binary to run the workload with. Default: $tool\n" .
    " --threads: comma-separated numbers of threads. Default: $threads\n" .
    " --tries: number of tries per test. Default: $tries\n" .
    "Note: results are printed to standard error; PARSEC messages are printed to standard output.\n" .
    "\n" .
    "Example:\n" .
    "./$name --benchmark=blackscholes --size=simsmall --tool=$tool --threads=1,2,16 --tries=3 2>parsec-out.dat\n" .
    "    Runs the blackscholes benchmark with the small input, using the\n" .
    "    $tool tool (i.e. running natively) for 1,2 and 16 threads.\n" .
    "    Results are averaged from 3 runs, and are saved to parsec-out.dat\n" .
    "    in gnuplot format.\n";

GetOptions (
    'benchmark=s' => \$test,
    'h|help' => \$help,
    'size=s' => \$size,
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

my $parsec_path = 'parsec-full';
my $bind_path = 'cputopology-perl/list.pl';

foreach my $th (@threads) {
    my @res = ();
    for (my $i = 0; $i < $tries; $i++) {
	my $bind = `$bind_path --policy=compact $th`;
	chomp($bind);
	my $cmd = "taskset -c $bind ";
	$cmd .= "$parsec_path/bin/parsecmgmt -a run -x pre -c gcc-hooks -i $size -n $th -p $test -s $tool";

	print "$test\n";
	print "$cmd\n";
	my $fh;
	my $pid = open($fh, "$cmd 2>&1 | ") or die "cannot open: $?";
	my $ROI;
	while (my $line = <$fh>) {
	    print $line;
	    if ($line =~ /\s+spent in ROI:\s+([0-9.]+)s/) {
		$ROI = $1;
	    }
	}
	close $fh;
	die if (!defined($ROI));
	push @res, $ROI;
    }
    print STDERR join("\t", $th, Mean::arithmetic(\@res), Mean::stdev(\@res)), "\n";
}

sub sys {
    my $cmd = shift(@_);
    system("$cmd") == 0 or die "cannot run '$cmd': $?";
}
