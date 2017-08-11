package Webmentions;

use diagnostics;
use strict;
use warnings;

use Encode;
use LWP::UserAgent;
use JSON::PP;
use CGI qw(:standard);
use LWP::Simple;

use API::Files;
use API::Build;

sub webmentions {
    my $tmp_hash = shift;

    my $q = new CGI;

    my $request_method = $q->request_method();

    if ( $request_method ne "POST" ) {
        report_error("400", "Invalid request or action", "Request method = $request_method. Action = $tmp_hash->{1}");
    }

    my $source_url = $q->param("source");
    $source_url = Utils::trim_spaces($source_url);
    if ( !defined($source_url) || length($source_url) < 1 )  { 
        report_error("400", "source_not_found", "The source URI does not exist.");
    } 

    my $target_url = $q->param("target");
    $target_url = Utils::trim_spaces($target_url);
    if ( !defined($target_url) || length($target_url) < 1 )  { 
        report_error("400", "target_not_found", "The target URI does not exist.");
    } 

    my $source_content = get($source_url);    
    if ( !$source_content ) {
        report_error("400", "source_not_found", "The source URI does not exist.");
    }

    my $target_content = get($target_url);    
    if ( !$target_content ) {
        report_error("400", "target_not_found", "The target URI does not exist.");
    }

#    if ( ($source_content !~ m|$target_url[\D]|) ) {
    if ( ($source_content !~ m|$target_url|is) ) {
        report_error("400", "no_link_found", "The source URI does not contain a link to the target URI.");
    } 

    my $webmentions_filename = Config::get_value_for("default_doc_root") . "/" . Config::get_value_for("webmentions_file");

    my $webmentions_text;
 
    if ( -e $webmentions_filename ) {
        open(my $fh, "<", $webmentions_filename ) or report_error("500", "Could not open links JSON file for read.", $!);
        while ( <$fh> ) {
            # chomp;
            $webmentions_text .= $_; 
        }
        close($fh) or report_error("500", "Could not close links JSON file after reading.", $!);
    } else {
        report_error("500", "Could not read webmentinos text file.", "File not found.");
    }

    my $before;
    my $after; 
    my $youngest_to_oldest = 0;
    if ( $webmentions_text =~ m/(.+)<!-- insert -->(.*)/is ) {
        $before = $1;
        $before .= "<!-- insert -->\n\n";
        $after  = $2;
        $youngest_to_oldest = 1;
    }

    if ( $webmentions_text =~ m/$source_url/ ) {
        report_error("400", "already_registered", "The specified WebMention has already been registered.");
    }

    my $dt_hash_ref     = Utils::create_datetime_stamp();

    if ( $youngest_to_oldest ) {
        $webmentions_text = $before . "$dt_hash_ref->{date} $dt_hash_ref->{time}\n" . "source=<$source_url>\ntarget=<$target_url>\n" . $after;
    } else {
        $webmentions_text = $webmentions_text . "\n\n$dt_hash_ref->{date} $dt_hash_ref->{time}\n" . "source=<$source_url>\ntarget=<$target_url>";
    } 

    if ( $webmentions_filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $webmentions_filename = $1;
    } else {
        report_error("500", "Bad file name.", "Could not write webmentions text file. $!");
    }
    open FILE, ">$webmentions_filename" or report_error("500", "Unable to open webmentions text file for write.", $!);
    print FILE $webmentions_text . "\n";
    close FILE;

    my $markup = Encode::decode_utf8($webmentions_text);

    my $hash = {
        'submit_type' => "Preview",
        'markup'      => $markup,
        'preview_only_key' => 'anything-can-be-used',
    };

    my $return_hash = Build::rebuild_html($hash);    

    my $rc = $return_hash->{status};

    if ( $rc >= 200 and $rc < 300 ) {
        _create_html_file($return_hash, $markup);
    } elsif ( $rc >= 400 and $rc < 500 ) {
         report_error("400", "$return_hash->{description}", "$return_hash->{user_message} $return_hash->{system_message}");
    } else  {
         report_error("500", "Unable to complete request. Invalid response code returned from API.", "$return_hash->{user_message} $return_hash->{system_message}");
    }

    my $json = <<JSONMSG;
{"result": "WebMention was successful"}
JSONMSG

    print header('application/json', '200 OK');
    print $json;
    exit;

# report_error("400", "webmention_filename = $webmentions_filename", "so far so good");

}

sub _create_html_file {
    my $hash_ref = shift;
    my $markup = shift;

    delete($hash_ref->{description});

#    if ( !Files::output("rebuild", $hash_ref, $markup) ) {
    if ( !Files::output("webmention", $hash_ref, $markup) ) {
       report_error("500", "Unable to create files.", "Unknown error.");
    }

    Files::_save_markup_to_storage_directory("update", $markup, $hash_ref);

}

sub report_error {
    my $error_code = shift;
    my $error = shift;
    my $description = shift;

        my $json = <<JSONMSG;
{"error": "$error","error_description": "$description"}
JSONMSG

        print header('application/json', "$error_code Bad Request");
        print $json;
        exit;
}

sub send_webmention_to_bridgy {
    my $source_url = shift;
    my $syn_to = shift;


    my $target_url = Config::get_value_for("bridgy_target_url_" . $syn_to);

    my $webmention_endpoint_url = Config::get_value_for("bridgy_webmention_endpoint_" . $syn_to);

    my $form_hash_ref = {
        'source' => $source_url,
        'target' => $target_url,
    };

    my $ua = LWP::UserAgent->new;
    my $response = $ua->post($webmention_endpoint_url, $form_hash_ref);
    my @rc = split(/ /, $response->status_line);
    my $rc = $rc[0];

    my $returned_json_hash_ref = decode_json $response->content;

    if ( $rc >= 200 and $rc < 300 ) {
        return 1;    
    } elsif ( $rc >= 400 and $rc < 500 ) {
        Error::report_error("400", "Failed to send Webmention.", "error = " . $returned_json_hash_ref->{error} . " error_description = " . $returned_json_hash_ref->{error_description}); 
    } else {
        Error::report_error("400", "Failed to send Webmention.", "Unknown reasons for the failure.");
    }         
}


# http://webmention.org
# WebMention defines several error cases that must be handled.
# All errors below MUST be returned with an HTTP 400 Bad Request response code.
#   source_not_found: The source URI does not exist.
#   target_not_found: The target URI does not exist. This must only be used when an external GET on the target URI would result in an HTTP 404 response.
#   target_not_supported: The specified target URI is not a WebMention-enabled resource. For example, on a blog, individual post pages may be WebMention-enabled but the home page may not.
#   no_link_found: The source URI does not contain a link to the target URI.
#   already_registered: The specified WebMention has already been registered.

sub send_webmention {
    my $source_url = shift;
    my $target_url = shift;

    my $web_protocol;
    my $domain_name;
    my $uri;


    if ( $target_url =~ m/(http[s]?):\/\/([^\/]*)[\/](.*)/igs ) {
        $web_protocol = $1;
        $domain_name  = $2;
        $uri          = $3;

        my $target_homepage_url = $web_protocol . "://" . $domain_name;

        my $ua = LWP::UserAgent->new;
        my $target_homepage_response = $ua->get($target_homepage_url);

        # <link rel="webmention" href="http://targetsite.com/webmention" />

        if ( $target_homepage_response->content =~ m/<link[\s]*
            rel[\s]*=[\s]*
            "webmention"[\s]*
            href[\s]*
            =[\s]*
            "(.*?)"
            [\s]*
            [\/]?>/isx ) {

            my $webmention_endpoint_url = $1;

            my $form_hash_ref = {
                'source' => $source_url,
                'target' => $target_url,
            };

            my $response = $ua->post($webmention_endpoint_url, $form_hash_ref);
            my @rc = split(/ /, $response->status_line);
            my $rc = $rc[0];

            my $returned_json_hash_ref = decode_json $response->content;

            if ( $rc >= 200 and $rc < 300 ) {
                return 1;    
            } elsif ( $rc >= 400 and $rc < 500 ) {
                Error::report_error("400", "Failed to send Webmention.", "error = " . $returned_json_hash_ref->{error} . " error_description = " . $returned_json_hash_ref->{error_description}); 
            } else {
                Error::report_error("400", "Failed to send Webmention.", "Unknown reasons for the failure.");
            }         
            
        } else {
            Error::report_error("400", "Failed to send Webmention.", "Unable to parse web mention endpoint from target homepage");
        }
    }
}

1;
