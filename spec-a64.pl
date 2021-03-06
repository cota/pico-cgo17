#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Long;
use Cwd;

my $run_spec = 'runspec-simple/spec06.pl';
my $spec_path = 'spec06-aarch64';
my $config = 'aarch64';

my $tries = 1;
my $tool = 'bin/aarch64-baseline';
my $size = 'test';
my $bench = 'perlbench';
my $help;

my $name = 'spec-a64.pl';
my $usage = "$name [options]\n" .
    "Options:\n" .
    " --bench  SPEC benchmark to run. Default: $bench.\n" .
    "          Special names: int, fp, all.\n" .
    " --size:  test, train, ref. Default: $size\n" .
    " --tool:  binary to run the SPEC executables with. Default: $tool\n" .
    " --tries: number of tries per executable. Default: $tries\n" .
    "\n" .
    "Example:\n" .
    "./$name --bench=gcc --size=test --tool=$tool --tries=3 1>spec-a64-out.dat\n" .
    "    Runs Aarch64 SPEC's gcc benchmark with the test input size under the\n" .
    "    $tool emulator. Results are averaged from 3 runs.\n" .
    "    Results are saved to spec-a64-out.dat in gnuplot format.\n";

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

