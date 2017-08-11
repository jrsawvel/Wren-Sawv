#!/usr/bin/perl -wT

use strict;
$|++;


use lib '../lib/CPAN';
use lib '../lib';


use REST::Client;
use JSON::PP;
use HTML::Entities;
use Encode;
use Data::Dumper;
use Shared::Page;
use Shared::Config;
use API::Files;


my $num_args = $#ARGV + 1;
if ($num_args != 1) {
    print "\nUsage: rebuildhtml.pl markdown-file\n";
    exit;
}
 
my $api_url = Config::get_value_for("api_url");
my $links_json_file = Config::get_value_for("links_json_file");
my $home_page_url = Config::get_value_for("home_page");

my $text_file = $ARGV[0];

my $original_markup;

open(my $fh, "<", $text_file) or die "cannot open $text_file for read: $!";
while ( <$fh> ) {
#    chomp;
    $original_markup .= $_; 
}
close($fh) or warn "close failed: $!";


    my $markup = Encode::decode_utf8($original_markup);
#    $markup = HTML::Entities::encode($markup,'^\n^\r\x20-\x25\x27-\x7e');


    my $hash = {
        'submit_type' => "Preview",
        'markup'      => $markup,
        'preview_only_key' => 'anything-can-be-used',
    };

    my $json_input = encode_json $hash;

    my $headers = {
        'Content-type' => 'application/json'
    };

    my $rest = REST::Client->new( {
        host => $api_url,
    } );

    $rest->POST( "/posts" , $json_input , $headers );

    my $rc = $rest->responseCode();

    my $json = decode_json $rest->responseContent();

    if ( $rc >= 200 and $rc < 300 ) {
        _create_html_file($json);
    } elsif ( $rc >= 400 and $rc < 500 ) {
         die "$json->{description} $json->{user_message} $json->{system_message}";
    } else  {
         die "Unable to complete request. Invalid response code returned from API. $json->{user_message} $json->{system_message}";
    }
   

sub _create_html_file {
    my $hash_ref = shift;

    delete($hash_ref->{description});

    if ( !Files::output("rebuild", $hash_ref, $markup) ) {
       Error::report_error("400", "Unable to create files.", "Unknown error.");
    }

}

__END__



test.md

==========


# Test Post - 28Apr2016

Hello **world**

* bullet point one
* bullet point two

Some *emphasis.*

A link to [Perl.org](http://perl.org).


==========


./md2html.pl test.md


==========


returned json:

{
  "status":200,
  "description":"OK",
  "post_type":"article",
  "title":"Test Post - 28Apr2016",
  "slug":"test-post-28apr2016",
  "author":"cawr",
  "created_time":"21:36:20 Z",
  "created_date":"Thu, 28 Apr 2016",
  "word_count":14
  "reading_time":0,
  "toc":0,
  "html":"<p>Hello <strong>world</strong></p>\n\n<ul>\n<li>bullet point one</li>\n<li>bullet point two</li>\n</ul>\n\n<p>Some <em>emphasis.</em></p>\n\n<p>A link to <a href=\"http://perl.org\">Perl.org</a>.</p>\n\n",
}

