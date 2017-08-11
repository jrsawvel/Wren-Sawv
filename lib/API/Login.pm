package Login;

use strict;
use warnings;
use diagnostics;

use WWW::Mailgun;
use API::DigestMD5;
use JSON::PP;

sub create_and_send_no_password_login_link {

    my $q = new CGI;

    my $json_text = $q->param('POSTDATA');

    my $hash_ref_login = decode_json $json_text;

    my $user_submitted_email = Utils::trim_spaces($hash_ref_login->{'email'});
    my $client_url           = Utils::trim_spaces($hash_ref_login->{'url'});

    if ( !$user_submitted_email or !$client_url ) {
        Error::report_error("400", "Invalid input.", "Insufficent data was submitted.");
    }

    my $author_email = Config::get_value_for("author_email");
    my $backup_author_email = Config::get_value_for("author_email_2");

    my $digest = "";

    my $date_time_ref = Utils::create_datetime_stamp();

    if ( $user_submitted_email ne $author_email  and  $user_submitted_email ne $backup_author_email ) {
        Error::report_error("400", "Invalid input.", "Data was not found.");
    } else {
        $digest = _create_session_id($date_time_ref);  # and return the login digest to be emailed
        _send_login_link($author_email, $digest, $client_url, $date_time_ref);
        _send_login_link($backup_author_email, $digest, $client_url, $date_time_ref);
    }

    my $hash_ref;

    $hash_ref->{session_id_digest} = $digest if Config::get_value_for("debug_mode"); 

    $hash_ref->{status}          = 200;
    $hash_ref->{description}     = "OK";
    $hash_ref->{user_message}    = "Creating New Login Link";
    $hash_ref->{system_message}  = "A new login link has been created and sent.";

    my $json_str = encode_json $hash_ref;

    print CGI::header('application/json', '200 Accepted');
    print $json_str;
    exit;
}

sub _send_login_link {
    my $email_rcpt      = shift;
    my $digest          = shift;
    my $client_url      = shift;
    my $date_time_ref   = shift;

    my $mailgun_api_key = Config::get_value_for("mailgun_api_key");
    my $mailgun_domain  = Config::get_value_for("mailgun_domain");
    my $mailgun_from    = Config::get_value_for("mailgun_from");

    my $home_page = Config::get_value_for("home_page");
    my $link      = "$client_url/$digest";

    my $site_name = Config::get_value_for("site_name");
    my $subject = "$site_name Login Link - $date_time_ref->{date} $date_time_ref->{time}";

    my $message = "Clink or copy link to log into the site.\n\n$link\n";

    my $mg = WWW::Mailgun->new({ 
        key    => "$mailgun_api_key",
        domain => "$mailgun_domain",
        from   => "$mailgun_from"
    });

    $mg->send({
          to      => "<$email_rcpt>",
          subject => "$subject",
          text    => "$message"
    });

}

sub _create_session_id {

    my $epoch_secs = time();

    my $random_string = Utils::create_random_string();

    my $session_id = DigestMD5::create($epoch_secs, $random_string, Config::get_value_for("author_email"));
    $session_id =~ s|[^\w]+||g;

    _write_session_id_to_file($random_string, $epoch_secs, $session_id, "pending", 0);

    return $random_string;
}

sub _write_session_id_to_file {
    my $random_string = shift;
    my $created_secs  = shift;
    my $session_id    = shift;
    my $status        = shift;
    my $updated_secs  = shift;

    my $session_id_file = Config::get_value_for("session_id_storage") . "/" . $random_string . ".txt";  
    if ( $session_id_file =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $session_id_file = $1;
    } else {
        Error::report_error("500", "Bad file name.", "Could not write session ide info.");
    }
    open FILE, ">$session_id_file" or Error::report_error("500", "Unable to open file for write.", "Cannot log in.");
    print FILE "$created_secs:$session_id:$status:$updated_secs\n";
    close FILE;
}

sub activate_no_password_login {

    my $q   = new CGI;

    my $rev = $q->param("rev"); # the random_string created above and sent to the author

    my $error_exists = 0;

    my $session_id = _get_session_id($rev);

    if ( !$session_id ) {
        Error::report_error("400", "Unable to login.", "Invalid session information submitted.");
    }

    my $hash_ref;

    $hash_ref->{author_name} = Config::get_value_for("author_name");
    $hash_ref->{session_id}  = $session_id;
    $hash_ref->{rev}         = $rev;
    $hash_ref->{status}      = 200;
    $hash_ref->{description} = "OK";

    my $json_str = encode_json $hash_ref;

    print CGI::header('application/json', '200 Accepted');
    print $json_str;
    exit;
}

# update random_string file name to change status for the session id from pending to active
# and return the session id.
sub _get_session_id {
    my $user_submitted_rev = shift; # the random_string created above and sent to the author

    # epoch_secs created : session_id : status (pending active deleted) : epoch_secs updated 

    my $session_id_file = Config::get_value_for("session_id_storage") . "/" . $user_submitted_rev. ".txt";  

    my $session_info;

    if ( -e $session_id_file ) {
        open(my $fh, "<", $session_id_file ) or Error::report_error("400", "Could not open session ID file for read.", $!);
        while ( <$fh> ) {
            chomp;
            $session_info = $_; 
        }
        close($fh) or Error::report_error("400", "Could not close session ID file after reading.", $!);
    } else {
        Error::report_error("400", "Could not read session ID file.", "File not found.");
    }

    my @session_array = split(/:/, $session_info);

    my $created_secs  = $session_array[0];
    my $session_id    = $session_array[1];
    my $status        = $session_array[2];
    my $updated_secs  = $session_array[3];
 
    if ( $status ne "pending" ) {
        return 0;
    }

    $status = "active";
    $updated_secs = time();

    _write_session_id_to_file($user_submitted_rev, $created_secs, $session_id, $status, $updated_secs);

    return $session_id;
}

1;
