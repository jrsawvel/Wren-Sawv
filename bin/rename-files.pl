#!/usr/bin/perl -wT

use strict;
use warnings;
use diagnostics;


my $num_args = $#ARGV + 1;
if ($num_args != 1) {
    print "\nUsage: rename-files.pl file-list \n";
    exit;
}

my $text_file = $ARGV[0];

open(my $fh, "<", $text_file) or die "cannot open $text_file for read: $!";
while ( <$fh> ) {
    chomp;
    my $orig = $_;
    my $new = $orig;
    $new  =~ s/^boghop.com-/sawv.org-/;
    print "mv -i $orig $new \n";
}
close($fh) or warn "close failed: $!";
