package Searches;

use diagnostics;
use strict;
use warnings;

use URI::Escape;
use JSON::PP;
use API::Auth;

sub searches {
    my $tmp_hash = shift;

    my $q   = new CGI;
    my $author_name = $q->param("author");
    my $session_id  = $q->param("session_id");
    my $rev         = $q->param("rev");
    if ( !Auth::is_valid_login($author_name, $session_id, $rev) ) { 
        Error::report_error("400", "Unable to peform action.", "You are not logged in.");
    }

    my $search_text = $tmp_hash->{1};

    $search_text = uri_unescape($search_text);

    # if the more friendly + signs are used for spaces in query string instead of %20, deal with it here.
    $search_text =~ s/\+/ /g;

    # remove unnacceptable chars from the search string
    $search_text =~s/[^A-Za-z0-9 _\-\#\.]//gs; 

    #clean up environment
    delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};
    $ENV{'PATH'} = '/bin:/usr/bin';

    my $default_doc_root = Config::get_value_for("default_doc_root");

    my $grep_cmd = "grep -i -R --exclude-dir=versions --include='*.txt' -m 1 '$search_text' " . $default_doc_root;

    if ( $grep_cmd =~ m|^([-A-Za-z0-9_/.~=*'"\#\. ]+)$| ) {
        $grep_cmd = $1;
    } else {
        Error::report_error("400", "Unable to execute search.", "Invalid characters used in the command.");
    }

    my @grep_result = `$grep_cmd`;

    my $total_hits = @grep_result;

    my $home_page = Config::get_value_for("home_page");

    my @posts;

    foreach my $result (@grep_result) {
         my @tmp = split(/\.txt:/, $result);
         $tmp[0] =~ s|\./||; 
         $tmp[0] =~ s|$default_doc_root/||;
         my $tmp_hash_ref;
         $tmp_hash_ref->{uri} = $tmp[0];
         $tmp_hash_ref->{url} = $home_page . "/" . $tmp[0] . ".html";
         push(@posts, $tmp_hash_ref);                         
    }

    my $hash_ref;
    $hash_ref->{status}      = 200;
    $hash_ref->{description} = "OK";
    $hash_ref->{total_hits}  = $total_hits;
    $hash_ref->{search_text} = $search_text;
    $hash_ref->{posts}       = \@posts;
    my $json_str = encode_json $hash_ref;

    print CGI::header('application/json', '200 Accepted');
    print $json_str;
    exit;
}

1;

