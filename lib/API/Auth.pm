package Auth;

use strict;
use warnings;
use diagnostics;

sub is_valid_login {
    my $submitted_author_name = shift;
    my $submitted_session_id  = shift;
    my $submitted_rev         = shift;

    my $author_name = Config::get_value_for("author_name");
    return 0 if $submitted_author_name ne $author_name;

    my %session_hash = _get_session_info($submitted_rev);

    return 0 if $submitted_session_id ne $session_hash{session_id};

    return 0 if $session_hash{'status'} ne "active";

    return 1;
}

sub _get_session_info {
    my $user_submitted_rev = shift;

    my $session_id_file = Config::get_value_for("session_id_storage") . "/" . $user_submitted_rev. ".txt";  

    my $session_record;

    if ( -e $session_id_file ) {
        open(my $fh, "<", $session_id_file ) or Error::report_error("400", "Could not open session ID file for read.", $!);
        while ( <$fh> ) {
            chomp;
            $session_record = $_; 
        }
        close($fh) or Error::report_error("400", "Could not close session ID file after reading.", $!);
    } else {
        Error::report_error("400", "Could not read session ID file.", "File not found.");
    }

    my @session_array = split(/:/, $session_record);

    my %session_hash;
    $session_hash{created_secs} = $session_array[0];
    $session_hash{session_id}   = $session_array[1];
    $session_hash{status}       = $session_array[2];
    $session_hash{updated_secs} = $session_array[3];
    $session_hash{rev}          = $user_submitted_rev;

    return %session_hash;
}

1;

