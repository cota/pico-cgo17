#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Long;
use Cwd;

my $run_spec = 'runspec-simple/spec06.pl';
my $spec_path = 'spec06';
my $config = 'x86_64';

my $tries = 1;
my $tool = '/usr/bin/time';
my $size = 'test';
my $bench = 'perlbench';
my $help;

my $name = 'spec.pl';
my $usage = "$name [options]\n" .
    "Options:\n" .
    " --bench  SPEC benchmark to run. Default: $bench.\n" .
    "          Special names: int, fp, all.\n" .
    " --size:  test, train, ref. Default: $size\n" .
    " --tool:  binary to run the SPEC executables with. Default: $tool\n" .
    " --tries: number of tries per executable. Default: $tries\n" .
    "\n" .
    "Example:\n" .
    "./$name --bench=gcc --size=test --tool=$tool --tries=2 1>spec-out.dat\n" .
    "    Runs SPEC's gcc benchmark with the test input size under the\n" .
    "    $tool tool (i.e. running natively). Results are averaged from 2 runs.\n" .
    "    Results are saved to spec-out.dat in gnuplot format.\n";

GetOptions (
    'bench=s' => \$bench,
    'h|help' => \$help,
    'size=s' => \$size,
    'tool=s' => \$tool,
    'tries=i' => \$tries,
    );

if (defined($help)) {
    print $usage;
    exit 0;
}

if ($tool !~ /^\//) {
    my $cwd = getcwd;
    $tool = "$cwd/$tool";
}
if (! -e $tool) {
    die "$tool does not exist";
}

my $cmd = "numactl -m 0 --physcpubind=0 $run_spec run ";
$cmd .= "$tool $spec_path $bench --iterations=$tries --size=$size --config=$config";

sys($cmd);

sub sys {
    my $cmd = shift(@_);
    system("$cmd") == 0 or die "cannot run '$cmd': $?";
}

