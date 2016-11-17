#!/usr/bin/perl

use warnings;
use strict;

use Time::HiRes qw(gettimeofday tv_interval);

BEGIN {push @INC, 'paper'}
use Mean;

use Getopt::Long;
use Data::Dumper;

my @tags = ('baseline', 'xxhash-mru', 'xxhash-nomru', 'xxhash-ck_hs', 'xxhash-qht');

my $bits = '13,18';
my $tries = 2;
my $out;
my $help;

my $usage = "hash.pl --out=outfile [options]\n" .
    " --out: path to output file with all the data in gnuplot format. Mandatory.\n" .
    "Options:\n" .
    " --bits: comma-separated numbers of bits (log2 number of initial buckets) to test. Default: $bits\n" .
    " --tries: number of tries per test. Default: $tries\n";

GetOptions (
    'bits=s' => \$bits,
    'h|help' => \$help,
    'tries=i' => \$tries,
    'out=s' => \$out,
    );

if (defined($help)) {
    print $usage;
    exit 0;
}

die if !$out;

my @bits = split(',', $bits);

my $qemu_path = $ENV{'QEMU_PATH'} ? $ENV{'QEMU_PATH'} : 'qemu';
my $bind_path = $ENV{'BIND_PATH'} ? $ENV{'BIND_PATH'} : 'cputopology-perl/list.pl';

my $results;

foreach my $tag (@tags) {
    sys("cd $qemu_path && git checkout -- .");
    sys("cd $qemu_path && git checkout $tag");

    foreach my $bits (@bits) {
	my @res = ();
	sys("perl -p -i -e 's/define CODE_GEN_PHYS_HASH_BITS.*/define CODE_GEN_PHYS_HASH_BITS $bits/' $qemu_path/include/exec/exec-all.h 1>&2");
	sys("perl -p -i -e 's/define CODE_GEN_HTABLE_BITS.*/define CODE_GEN_HTABLE_BITS $bits/' $qemu_path/include/exec/exec-all.h 1>&2");
	sys("make -j 6 -C $qemu_path >/dev/null");

	for (my $i = 0; $i < $tries; $i++) {
	    my $cmd = "taskset -c 0 $qemu_path/arm-softmmu/qemu-system-arm -machine type=virt -nographic -smp 1 -m 4096 -netdev user,id=unet,hostfwd=tcp::2222-:22 -device virtio-net-device,netdev=unet -drive file=img/arm/jessie-arm32-die-on-boot.qcow2,id=myblock,index=0,if=none -device virtio-blk-device,drive=myblock -kernel img/arm/aarch32-current-linux-kernel-only.img -append 'console=ttyAMA0 root=/dev/vda1' -name arm,debug-threads=on -smp 1 -tb-size 1024";
	    my $fh;
	    my $t0 = [gettimeofday];
	    my $pid = open($fh, "$cmd | ") or die "cannot open: $?";
	    while (my $line = <$fh>) {
		;
	    }
	    my $walltime = tv_interval($t0);
	    close $fh;
	    push @res, $walltime;
	}

	$results->{$tag}->{$bits}->{mean} = Mean::arithmetic(\@res);
	$results->{$tag}->{$bits}->{stddev} = Mean::stdev(\@res);
    }
}

sub sys {
    my $cmd = shift(@_);
    system("$cmd") == 0 or die "cannot run '$cmd': $?";
}

print Dumper($results);

open(my $fh, ">", $out) or die "cannot open '$out': $!";
print $fh "# ", join("\t", @tags), "\n";
foreach my $bits (@bits) {
    my @arr = ($bits);
    foreach my $tag (@tags) {
	my $r = $results->{$tag}->{$bits};
	push @arr, $r->{mean}, $r->{stddev};
    }
    print $fh join("\t", @arr), "\n";
}
