#!/usr/bin/perl

use warnings;
use strict;

use Time::HiRes qw(gettimeofday tv_interval);

BEGIN {push @INC, '..'}
use Mean;

use Getopt::Long;
use Data::Dumper;

my $tries = 2;
my $duration = 5;
my $range = 200000;
my $threads = '1,2';
my %options = (
    'qht' => {
	'flag' => '',
    },
    'clht' => {
	'flag' => '-C',
    },
    'ck' => {
	'flag' => '-c',
    },
);

my $out;
my $u = 0;
my $help;

my $usage = "qht.pl --out=outfile [options]\n" .
    " --out: path to output file with all the data in gnuplot format. Mandatory.\n" .
    "Options:\n" .
    " --duration: duration, in seconds. Default: $duration\n" .
    " --range: key range. Default: $range\n" .
    " --threads: comma-separated numbers of threads. Default: $threads\n" .
    " --tries: number of tries per test. Default: $tries\n" .
    " --update_rate: update rate for all tests. Default: $u\n";

GetOptions (
    'duration=i' => \$duration,
    'h|help' => \$help,
    'out=s' => \$out,
    'range=i' => \$range,
    'threads=s' => \$threads,
    'tries=i' => \$tries,
    'update_rate=f' => \$u,
    );

if (defined($help)) {
    print $usage;
    exit 0;
}

die "--out parameter is mandatory\n" if !$out;
my $qemu_path = $ENV{'QEMU_PATH'} ? $ENV{'QEMU_PATH'} : 'qemu';
my $bind_path = $ENV{'BIND_PATH'} ? $ENV{'BIND_PATH'} : 'cputopology-perl/list.pl';

my @threads = split(',', $threads);

my $results;

my @tests = ('qht', 'clht', 'ck');

foreach my $test (@tests) {
    die if !$options{$test};
}

foreach my $test (@tests) {
    foreach my $n (@threads) {
	my @res = ();
	for (my $i = 0; $i < $tries; $i++) {
	    my $flags = "-d $duration -n $n -u $u -k $range -K $range -l $range -r $range -s $range $options{$test}->{flag}";
	    my $bind = `$bind_path --policy=compact $n`;
	    chomp($bind);
	    my $cmd = "taskset -c $bind bin/x86_64-test-qht-par $flags";
	    print "$cmd\n";
	    my $fh;
	    my $pid = open($fh, "$cmd 2>&1 | ") or die "cannot open: $?";
	    my $throughput;
	    while (my $line = <$fh>) {
		print $line;
		if ($line =~ /\s+Throughput:\s+([0-9.]*) MT/) {
		    $throughput = $1;
		}
	    }
	    die if (!$throughput);
	    close $fh;
	    push @res, $throughput;
	}

	$results->{$test}->{$n}->{mean} = Mean::arithmetic(\@res);
	$results->{$test}->{$n}->{stddev} = Mean::stdev(\@res);
    }
}

sub sys {
    my $cmd = shift(@_);
    system("$cmd") == 0 or die "cannot run '$cmd': $?";
}

print Dumper($results);

open(my $fh, ">", $out) or die "cannot open '$out': $!";
print $fh "# ", join("\t", @tests), "\n";
foreach my $n (@threads) {
    my @arr = ($n);
    foreach my $test (@tests) {
	my $r = $results->{$test}->{$n};
	push @arr, $r->{mean}, $r->{stddev};
    }
    print $fh join("\t", @arr), "\n";
}
