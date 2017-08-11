package Users;

use diagnostics;
use strict;
use warnings;

use API::Login;
use API::Logout;
use API::IndieAuth;

sub users {

    my $tmp_hash = shift;

    my $q = new CGI;

    my $request_method = $q->request_method();

    if ( $request_method eq "POST" ) {
        if ( exists($tmp_hash->{1}) and $tmp_hash->{1} eq "login" ) {
            Login::create_and_send_no_password_login_link();
        }
    } elsif ( $request_method eq "GET" ) {
        if ( exists($tmp_hash->{1}) and $tmp_hash->{1} eq "login" ) {
            Login::activate_no_password_login();
        } elsif ( exists($tmp_hash->{1}) and $tmp_hash->{1} eq "logout" ) {
            Logout::logout();
        } elsif ( exists($tmp_hash->{1}) and $tmp_hash->{1} eq "indieauthlogin" ) {
            IndieAuth::do_indie_auth_login();
        } elsif ( exists($tmp_hash->{1}) and $tmp_hash->{1} eq "auth" ) {
            IndieAuth::authenticate();
        }
    }

    Error::report_error("400", "Invalid request or action", "Request method = $request_method. Action = $tmp_hash->{1}");

}

1;
