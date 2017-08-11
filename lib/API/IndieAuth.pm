package IndieAuth;

use strict;
use warnings;
use diagnostics;

use LWP;
use API::Login;
use JSON::PP;
use URI::Escape;

# May 11, 2017 - this subroutine is unnecessary. 
sub do_indie_auth_login {

    my $url          = Config::get_value_for("indieauth_url");
    my $redirect_uri = Config::get_value_for("indieauth_redirect_url");
    my $client_id    = Config::get_value_for("indieauth_client_id");
    my $me           = Config::get_value_for("indieauth_me");

    $url .= "?me=$me&client_id=$client_id&redirect_uri=$redirect_uri";

    my ($doc, $status, $success, $resp) = do_GET($url);
   
    Error::report_error("400", "debug", "doc=$doc <br> status=$status <br> success=$success <br> resp=$resp");

}

sub authenticate {

    my $q   = new CGI;

    my $code = $q->param("code");

# Error::report_error("400", "debug code:", $code);

    my $url          = Config::get_value_for("indieauth_url");
    my $redirect_uri = Config::get_value_for("indieauth_redirect_url");
    my $client_id    = Config::get_value_for("indieauth_client_id");

    my ($doc, $status, $success, $resp) = _do_POST($url, [ 'code' => $code, 'redirect_uri' => $redirect_uri, 'client_id' => $client_id ],);
   
#    Error::report_error("400", "debug", "doc=$doc <br> status=$status <br> success=$success <br> resp=$resp");

    if ( $status == 200 ) {

        if ( $doc and length($doc) > 0 ) {
            my $me           = Config::get_value_for("indieauth_me");
            # returned info stored in doc = 
            # me=http%3A%2F%2Fmysite.com%2F&scope
            my $unescaped_doc = uri_unescape($doc);
            my @values = split(/&/, $unescaped_doc);
            my @url = split(/=/, $values[0]);
            if ( $me ne $url[1] ) {
                Error::report_error("400", "Unable to login.", "Wrong website submitted in login form.");
            }
        } else {
            Error::report_error("400", "Unable to login.", "Missing info from the IndieAuth server.");
        }

        my $date_time_ref = Utils::create_datetime_stamp();
          
        my $rev = Login::_create_session_id($date_time_ref);  
    
        # rev is the name of the file that contains the session id

        my $session_id = Login::_get_session_id($rev);
 
        if ( !$session_id ) {
            Error::report_error("400", "Unable to login.", "Invalid session information submitted.");
        }

        my $client_url = Config::get_value_for("indieauth_wren_redirect_url");

        $client_url .= "?author_name=" . Config::get_value_for("author_name") . "&session_id=$session_id&rev=$rev";
 
        print $q->redirect( -url => $client_url );
        exit;
    }        
}


sub _do_POST {
    # parameters:
    # the URL
    # an arrayref or hashref for the key/value pairs
    # and then, optionally, any header lines: (key, value, key,value)

    my $browser = LWP::UserAgent->new();
    my $resp = $browser->post(@_);

    return ($resp->content, $resp->status_line, $resp->is_success, $resp) if wantarray;

    return unless $resp->is_success;

    return $resp->content;

}

sub do_GET {
    my $browser = LWP::UserAgent->new;

    my $resp = $browser->get(@_);

    return ( $resp->content, $resp->status_line, $resp->is_success, $resp) if wantarray;

    return unless $resp->is_success;

    return $resp->content;
}

1;
