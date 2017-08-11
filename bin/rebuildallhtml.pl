#!/usr/bin/perl -wT

use strict;
$|++;

use lib '../lib/CPAN';
use lib '../lib';

use JSON::PP;
use HTML::Entities;
use Encode;
use Shared::Page;
use Shared::Config;
use API::Build;
use API::Files;


my $home_page_url = Config::get_value_for("home_page");
my $doc_root = Config::get_value_for("default_doc_root");
my $private_dir = Config::get_value_for("private_dir");

my $links_json_file = $private_dir . "/" . Config::get_value_for("links_json_file");

my $json_text;
 
if ( -e $links_json_file ) {
    open(my $fh, "<", $links_json_file ) or die "Could not open links JSON file for read. $!";
    while ( <$fh> ) {
        chomp;
        $json_text .= $_; 
    }
    close($fh) or die "Could not close links JSON file after reading. $!";
} else {
    die "[2] Could not read links JSON file. File not found.";
}

my $perl_hash = decode_json $json_text;
my $stream    = $perl_hash->{posts};

foreach my $post (@$stream) {
    $post->{link} =~ s|$home_page_url|$doc_root|;
    if ( $post->{link} =~ m|(.*)\.html$| ) {
        $post->{link} = $1;
    }
    my $markup_file = $post->{link} . ".txt";
    _rebuild_html_file($markup_file);
}  


sub _rebuild_html_file {
    my $text_file = shift;

#     my $api_url = Config::get_value_for("api_url");

    my $original_markup;

    my $fh;

    my $result = eval {
        open($fh, "<", $text_file)
    };

    unless ( $result ) {
        warn "cannot open $text_file for read: $!";
        return;
    }

    while ( <$fh> ) {
        $original_markup .= $_; 
    }
    close($fh) or warn "close failed: $!";

    my $markup = Encode::decode_utf8($original_markup);

# this line is not needed because wren stores the markup files with extended ascii chars converted to entities.
#    $markup = HTML::Entities::encode($markup,'^\n^\r\x20-\x25\x27-\x7e');


    my $hash = {
        'submit_type' => "Preview",
        'markup'      => $markup,
        'preview_only_key' => 'anything-can-be-used',
    };

    my $return_hash = Build::rebuild_html($hash);    

    my $rc = $return_hash->{status};

    if ( $rc >= 200 and $rc < 300 ) {
        _create_html_file($return_hash, $markup);
    } elsif ( $rc >= 400 and $rc < 500 ) {
         die "$return_hash->{description} $return_hash->{user_message} $return_hash->{system_message}";
    } else  {
         die "Unable to complete request. Invalid response code returned from API. $return_hash->{user_message} $return_hash->{system_message}";
    }
}   


sub _create_html_file {
    my $hash_ref = shift;
    my $markup = shift;

    delete($hash_ref->{description});

    if ( !Files::output("rebuild", $hash_ref, $markup) ) {
       die "Unable to create files. Unknown error.";
    }
}

