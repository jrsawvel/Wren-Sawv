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
use Shared::Config;
use Shared::Page;

    my $user_submitted_email = "jothut\@fastmail.fm";

    if ( !$user_submitted_email ) {
        # die  "Invalid input. No data was submitted.";
        Page->report_error("user", "Invalid input.", "No data was submitted.");
    }

    my $headers = {
        'Content-type' => 'application/json'
    };

    my $rest = REST::Client->new( {
           host => Config::get_value_for("api_url"),
    } );

    my $hash_ref;
    $hash_ref->{email} = $user_submitted_email;
    $hash_ref->{url}   = Config::get_value_for("home_page") . "/wren/nopwdlogin";

    my $json_input = encode_json $hash_ref;
    $rest->POST( "/users/login" , $json_input , $headers );

    my $rc = $rest->responseCode();
    my $json = decode_json $rest->responseContent();

    if ( $rc >= 200 and $rc < 300 ) {
        # die "Creating New Login Link. A new login link has been created and sent.";
        Page->success("Creating New Login Link", "A new login link has been created and sent.", "");
    } elsif ( $rc >= 400 and $rc < 500 ) {
        # die "Unable to complete request. Invalid data provided. $json->{user_message} - $json->{system_message}";
        Page->report_error("user", "Unable to complete request.", "Invalid data provided. $json->{user_message} - $json->{system_message}");
    } else  {
        # die "Unable to complete request. Invalid response code returned from API. $json->{user_message} - $json->{system_message}";
        Page->report_error("user", "Unable to complete request.", "Invalid response code returned from API. $json->{user_message} - $json->{system_message}");
    }


