#!/usr/bin/perl -wT

use strict;
use diagnostics;
use warnings;
use Time::Local;

my $text_file  = "custom-rss-feed.txt";

open(my $fh, "<", $text_file) or die "cannot open $text_file for read: $!";

my $line_count=0;

my $dt = create_datetime_stamp();

my $rss_top = <<RSSTOP;
<rss xmlns:content="http://purl.org/rss/1.0/modules/content/" xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">
<channel>
<title>sawv</title>
<atom:link href="http://sawv.org/customrss.xml" rel="self" type="application/rss+xml"/>
<link>http://sawv.org</link>
<description>jr's notes</description>
<pubDate>$dt</pubDate>
<language>en-us</language>
<generator>Wren v1.0</generator>
<docs>http://cyber.law.harvard.edu/rss/rss.html</docs>
RSSTOP


print $rss_top;


while ( <$fh> ) {
    chomp;

    my $record = $_;

    if ( $line_count == 0 or length($record) < 5 ) {
        $line_count++;
        next;
    }

    my @arr = split /\|/, $record;

    print "<item>\n";
    print "<title>$arr[0]</title>\n";
    print "<description>$arr[1]</description>\n";
    print "<pubDate>$arr[2]</pubDate>\n";
    print "<guid>$arr[3]</guid>\n";
    print "<link>$arr[3]</link>\n";
    print "</item>\n";

}
close($fh) or warn "close failed: $!";

print "</channel>\n";
print "</rss>\n";



# creates date format as:
# Fri, 19 Jan 2018 20:21:04 Z
sub create_datetime_stamp {
    my $minutes_to_add = shift;

    if ( !$minutes_to_add ) {
        $minutes_to_add = 0;
    }

    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @dow = qw(Sun Mon Tue Wed Thu Fri Sat);

    my $epochsecs = time() + ($minutes_to_add * 60);
    my ($sec, $min, $hr, $mday, $mon, $yr, $wday)  = (gmtime($epochsecs))[0,1,2,3,4,5,6];

    my $hash_ref;
    $hash_ref->{date} = sprintf "%s, %02d %s %04d",  $dow[$wday], $mday, $months[$mon], 1900 + $yr;
    $hash_ref->{time} = sprintf "%02d:%02d:%02d Z",  $hr, $min, $sec;
    
#    return $hash_ref;
    return $hash_ref->{date} . " " . $hash_ref->{time}; 
}

