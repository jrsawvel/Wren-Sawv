package Read;

use strict;
use warnings;
use diagnostics;

use JSON::PP;
use CGI qw(:standard);
use API::Files;

sub get_post {
    my $post_id = shift;

    my $q = new CGI;
    my $logged_in_author_name  = $q->param("author");
    my $session_id             = $q->param("session_id");
    my $rev                    = $q->param("rev");

#    if ( !Auth::is_valid_login($logged_in_author_name, $session_id, $rev) ) { 
#        Error::report_error("400", "Unable to peform action.", "You are not logged in.");
#    }

    my $hash_ref; 

    $hash_ref->{status}            = 200;
    $hash_ref->{description}       = "OK";
    $hash_ref->{markup} = Files::read_markup_file($post_id);
    $hash_ref->{slug} = $post_id;
    my $json_str = encode_json $hash_ref;
    print header('application/json', '200 Accepted');
    print $json_str;
    exit;
}

1;
