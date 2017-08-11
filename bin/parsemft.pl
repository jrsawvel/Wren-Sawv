#!/usr/bin/perl -wT

use HTML::TokeParser;
use LWP::Simple;

use Data::Dumper;
use Time::Local;

my $num_args = $#ARGV + 1;
if ($num_args != 1) {
    print "\nUsage: parsemft.pl mfturl\n";
    exit;
}
 
my $source_url = $ARGV[0];

my $source_content = get($source_url);
 
my $p = HTML::TokeParser->new(\$source_content);

# print Dumper $p;

my $img_url;

my $token;

my @arr;

while ( $token = $p->get_tag('li') ) {
    my %tmp_hash;

    # if ( exists($token->[1]{class}) and $token->[1]{class} eq "h-entry" ) {
    if ( exists($token->[1]{class}) and $token->[1]{class} =~ m|h-entry| ) {
 
            if ( my $token3 = $p->get_tag("a") ) {
                my $url = $token3->[1]{href} || "-";
                my $text = $p->get_trimmed_text("/a");
                # print "$url\t$text\n";
                $tmp_hash{url}   = $url;
                $tmp_hash{title} = $text;
            }

            if ( my $token3 = $p->get_tag("div") ) {
                if ( exists($token3->[1]{class}) and $token3->[1]{class} eq "p-author" ) {
                    my $author = $p->get_trimmed_text("/div");
                    # print "author = $author\n";
                    $tmp_hash{author} = $author;
                }
            }

            if ( my $token3 = $p->get_tag('time') ) {
                if ( exists($token3->[1]{class}) and $token3->[1]{class} eq "dt-published" ) {
                    if ( exists($token3->[1]{datetime}) ) {
                        # print "datetime = $token3->[1]{datetime}" . " epoch = " . convert_date_to_epoch($token3->[1]{datetime}) .  "\n";
                        # print "datetime = $token3->[1]{datetime}" .  "\n";
                        $tmp_hash{datetime} = $token3->[1]{datetime}; 
                    }
                }     
           }
    }

    push(@arr, \%tmp_hash);
}

print Dumper \@arr;



# receives date string as: YYYY-MM-DD HH-MM-SS
# date format used in database date field
# code from: http://stackoverflow.com/users/4234/dreeves
# in post: http://stackoverflow.com/questions/95492/how-do-i-convert-a-date-time-to-epoch-time-aka-unix-time-seconds-since-1970
# I changed timelocal to timegm
sub convert_date_to_epoch {
  my($s) = @_;
  my($year, $month, $day, $hour, $minute, $second);

  if($s =~ m{^\s*(\d{1,4})\W*0*(\d{1,2})\W*0*(\d{1,2})\W*0*
                 (\d{0,2})\W*0*(\d{0,2})\W*0*(\d{0,2})}x) {
    $year = $1;  $month = $2;   $day = $3;
    $hour = $4;  $minute = $5;  $second = $6;
    $hour |= 0;  $minute |= 0;  $second |= 0;  # defaults.

# print " --- $hour $minute $second ---\n";

    $year = ($year<100 ? ($year<70 ? 2000+$year : 1900+$year) : $year);
    return timegm($second,$minute,$hour,$day,$month-1,$year);  
  }
  return -1;

}


__END__


Example entry contained within the Wren microformatted HTML file,
 found at http://website/mft.html
Wren creates mft.html automatically, each time a new post is created.  

<ul>
  <li class="h-entry">
    <a class="u-url" href="http://wren.soupmode.com/2016-nfl-draft.html">2016 NFL Draft</a>
    <div class="p-author" style="display:none;">cawr</div>
    <br /><time class="dt-published" datetime="Thu, 28 Apr 2016 14:30:38 Z">Thu, 28 Apr 2016 14:30:38 Z</time>
  </li>
</ul>



# ./parsemft.pl http://wren.soupmode.com/mft.html


Dump of the Perl hash:

          {
            'url' => 'http://wren.soupmode.com/2016-nfl-draft.html',
            'author' => 'cawr',
            'title' => '2016 NFL Draft',
            'datetime' => 'Thu, 28 Apr 2016 14:30:38 Z'
          },


I admire all the work done and evangelized by the IndieWeb group over the past number of years.

http://indiewebcamp.com

I like Webmentions as a possible commenting mechanism. I added Webmention support to my Junco web publishing app.

And I like the idea of Microformats, although I don't use them a lot.

http://microformats.org/wiki/microformats2

I don't subscribed to the idea, however, of abolishing RSS/Atom 100 percent for Microformats. I could see supporting multiple types of feeds: RSS, Atom, JSON, and Microformats.

The idea for Microformats is simpler though. The markup is contained within the HTML page. No need to create a separate formatted file. The homepage doubles as the feed page.

http://tantek.com/2013/272/t3/atom-feed-reduced-subscribe-home-page-h-entry

    Effective immediately:
        * Atom feed reduced to only 3 newest entries
        * subscribe to home page h-entry to get 20 entries 

Of course, this requires creating a feed reader that parses Microformats. I cannot use an RSS reader.

IndieWeb compatible: https://indiewebify.me

For Perl, I use the XML::FeedPP module that provides an easy-to-use object oriented interface to parse RSS/Atom feeds.

It seems silly to re-invent this process. Basic RSS is, well, basic and simple to create, understand, and parse. I don't understand why some choose to discard something that is simple, "old", and reliable for something that appears to me be a lot more complicated.

I'll continue to add microformats to HTML files, but for parsing, I'll stick with simple over complex.

From what little that I have observed, no standard method exists for marking up a homepage with microformats. 

My Perl script above is lame. It's lack of sophistication makes it unusable on other microformatted homepages. It works only with Wren's mft.html. 

Since RSS and Atom exist, and since I enjoy using the feed reader, http://theoldreader.com then I'm not motivated to create a generic script that reads the microformatted homepages of IndieWeb users.

Maybe I'll think about this later.

http://indiewebcamp.com/readers 

Interesting:

    * http://indiewebcamp.com/Shrewdness
    * https://waterpigs.co.uk/intertubes/new
    * https://waterpigs.co.uk/intertubes/feed


