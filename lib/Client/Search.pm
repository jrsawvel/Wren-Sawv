package Search;

use diagnostics;
use strict;
use warnings;

use REST::Client;
use JSON::PP;
use URI::Escape;
use LWP::UserAgent;
use Shared::Utils;
use Client::User;


sub search {
    my $tmp_hash = shift;

    my $author_name  = User::get_logged_in_author_name(); 
    my $session_id   = User::get_logged_in_session_id(); 
    my $rev          = User::get_logged_in_rev(); 

    if ( !$author_name or !$session_id or !$rev ) {
        Page->report_error("user", "Cannot peform action.", "You are not logged in.");
    }

    my $query_string = "/?author=$author_name&session_id=$session_id&rev=$rev";

    my $search_string= $tmp_hash->{1};

    if ( !defined($search_string) ) {
        my $q = new CGI;
        $search_string = $q->param("keywords");

        if ( !defined($search_string) ) {
            Page->report_error("user", "Missing data.", "Enter keyword(s) to search on.");
        }
        
        $search_string = Utils::trim_spaces($search_string);
        if ( length($search_string) < 1 ) {
            Page->report_error("user", "Missing data.", "Enter keyword(s) to search on.");
        }
    } else {
        $search_string = uri_unescape($search_string);
        $search_string =~ s/\+/ /g;
    }

    my $search_uri_str = $search_string;
    $search_uri_str =~ s/ /\+/g;
    $search_uri_str = uri_escape($search_uri_str);

    my $api_url = Config::get_value_for("api_url") . "/searches/$search_uri_str";
    $api_url .= $query_string;
# Page->report_error("user", $query_string, $api_url);

    my $ua       = LWP::UserAgent->new;
    my $response = $ua->get($api_url); 

    my $hash_ref = decode_json $response->content;

    my $rc = $hash_ref->{'status'};

    if ( $rc >= 400 and $rc <= 500 ) {
        Page->report_error("user", "$hash_ref->{user_message}", $hash_ref->{system_message});
    }

    if ( !$hash_ref->{total_hits} ) {
        Page->report_error("user", "No search results for:", "'$search_string'");
    }

    my $stream = $hash_ref->{'posts'};

    my $t = Page->new("searchresults");
    $t->set_template_loop_data("stream_loop", $stream);
    $t->set_template_variable("keyword", $search_string);
    $t->set_template_variable("search_uri_str", $search_uri_str);
    $t->display_page("Search results for $search_string");
}

1;
