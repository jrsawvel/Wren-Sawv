package Logout;

use strict;
use warnings;
use diagnostics;

use JSON::PP;

sub logout {

    my $q   = new CGI;

    my $author_name = $q->param("author");
    my $session_id  = $q->param("session_id");
    my $rev         = $q->param("rev");

    my $config_author_name = Config::get_value_for("author_name");

    if ( $config_author_name ne $author_name ) {
        Error::report_error("400", "Unable to logout.", "Invalid info submitted.");    
    }

    my $hash_ref = _read_session_info($rev); # return a reference to a hash;

    if ( $hash_ref->{status} ne "active" ) {
        Error::report_error("400", "Unable to logout.", "Invalid info submitted.");    
    }

    if ( $hash_ref->{session_id} ne $session_id ) {
        Error::report_error("400", "Unable to logout.", "Invalid info submitted.");    
    }

    $hash_ref->{status} = "deleted";

    _update_session_info($rev, $hash_ref);
    
    my $return_hash_ref;
    $return_hash_ref->{status}       = 200;
    $return_hash_ref->{description}  = "OK";
    $return_hash_ref->{logged_out}   = "true";

    my $json_return_str = encode_json $return_hash_ref;

    print CGI::header('application/json', '200 Accepted');
    print $json_return_str;
    exit;
}

sub _read_session_info {
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

    my $hash_ref; 
    $hash_ref->{created_secs}  = $session_array[0];
    $hash_ref->{session_id}    = $session_array[1];
    $hash_ref->{status}        = $session_array[2];
    $hash_ref->{updated_secs}  = $session_array[3];
 
    return $hash_ref;
}

sub _update_session_info {
    my $user_submitted_rev = shift; 
    my $hash_ref = shift; 

    my $session_id_file = Config::get_value_for("session_id_storage") . "/" . $user_submitted_rev . ".txt";  
    if ( $session_id_file =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $session_id_file = $1;
    } else {
        Error::report_error("500", "Bad file name.", "Could not write session ide info.");
    }
    open FILE, ">$session_id_file" or Error::report_error("500", "Unable to open file for write.", "Cannot log in.");
    print FILE "$hash_ref->{created_secs}:$hash_ref->{session_id}:$hash_ref->{status}:$hash_ref->{updated_secs}\n";
    close FILE;
}
1;

