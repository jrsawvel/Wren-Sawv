package Webmention;

use diagnostics;
use strict;
use warnings;

use REST::Client;
use JSON::PP;
use URI::Escape;
use LWP::UserAgent;
use Shared::Utils;


sub webmention {

    my $q = new CGI;

    my $source = Utils::trim_spaces($q->param("source"));
    if ( !defined($source) or length($source) < 1 ) {
        Page->report_error("user", "Missing data.", "Enter source URL.");
    }

    my $target = Utils::trim_spaces($q->param("target"));
    if ( !defined($target) or length($target) < 1 ) {
        Page->report_error("user", "Missing data.", "Enter target URL.");
    }

    my $headers = {
        'Content-type' => 'application/x-www-form-urlencoded'
    };

    my $rest = REST::Client->new( {
           host => Config::get_value_for("api_url"),
    } );

    $rest->POST( "/webmentions" , "source=$source&target=$target", $headers );

    my $rc = $rest->responseCode();
    my $json = decode_json $rest->responseContent();

    if ( $rc >= 200 and $rc < 300 ) {
            print $q->redirect( -url => "/webmentions.html");
            exit;
#        Page->success("Adding Webmention", "A new Webmention has been posted.", "");
    } elsif ( $rc >= 400 and $rc < 500 ) {
        Page->report_error("user", "Unable to complete request.", "$json->{error_description}");
    } else  {
        Page->report_error("user", "Unable to complete request.", "Invalid response code returned from API. $json->{error} - $json->{error_description}");
    }

}

1;

