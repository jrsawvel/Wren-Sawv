package Micropub;

use strict;
use warnings;
use diagnostics;

use HTML::Entities;
use URI::Escape::JavaScript qw(escape unescape);
use LWP;
use CGI qw(:standard);
use JSON::PP;
use API::PostTitle;
use API::Format;
use API::Files;


sub micropub {
    my $q = new CGI;

    my $request_method = $q->request_method();


    if ( $request_method eq "POST" ) {
        # holy hell. an update is also a POST request and not a PUT !!!???
        create();
    } elsif ( $request_method eq "GET" ) {
        # i'm not checking for the authorization bearer token because this only reads the markup.

        my $q_param   = $q->param("q");
        my $url = $q->param("url");
        my $post_id;

        my $home_page = Config::get_value_for("home_page");
        if ( $url =~ m/$home_page\/(.*).html$/i ) {
            $post_id = $1; # slug 
        } else {
            Error::report_error("400", "Invalid read request.", "URL to post is missing.");
        }

        my $markup = Files::read_markup_file($post_id);

        my $hash_ref = {
                           "type" => ["h-entry"],
                           "properties" => {
                                               "content"   => [$markup]
                                           }
                       };

        my $json_str = encode_json $hash_ref;

        print CGI::header('application/json', '200 OK');
        print $json_str;
        exit;
    }

}


sub create {

    my $q   = new CGI;

    my $json_hash_ref;
    my $in_reply_to;

    # it's irritating that the micropub spec supports both form-urlencoded and json.
    # i prefer only json. or better, i prefer that only one option exists. 
    # if the only option was form-urlencoded, then fine. but checking for both is annoying.
    # even when i select "json" in one particular client, the micropub sends 
    # form-urlencoded when it's a note. why? are all notes always form-urlencoded?
    # and why doe the clients include html tags within the markup when it's an article? jeesh.

    # x-www-form-urlencoded
    my $markup = $q->param("content");
    my $in_reply_to = $q->param("in-reply-to");
    my $action = "create";
    my $original_slug;  # post id

    if ( !$markup or length($markup) < 1 ) {
        # post made as json
        my $json_text = $q->param('POSTDATA');
        $json_hash_ref = decode_json $json_text;

        if ( ref $json_hash_ref->{properties}->{content}->[0] eq 'HASH' ) {
            # article 
            $markup = $json_hash_ref->{properties}->{content}->[0]->{html};
            my $tmp_title = $json_hash_ref->{properties}->{name}->[0];
            $markup = "# " . $tmp_title . "\n\n" . $markup; # default to Markdown
            $markup = URI::Escape::JavaScript::unescape($markup);
            $markup = HTML::Entities::encode($markup, '^\n\x20-\x25\x27-\x7e');
#            $markup = Utils::remove_html($markup);
        } else {
            # note
            # replies are always notes, according to micropub spec
            $markup      = $json_hash_ref->{properties}->{content}->[0];
            $in_reply_to = $json_hash_ref->{properties}->{'in-reply-to'}->[0];
        }


        if ( exists($json_hash_ref->{action}) ) {
            $action = $json_hash_ref->{action}; 
            if ( $action eq "update") {
                # man, i dislike micropub's json usage. my json wren api is simpler and easier.
                $markup = $json_hash_ref->{replace}->{content}->[0];
                my $url = $json_hash_ref->{url};
                my $home_page = Config::get_value_for("home_page");
                if ( $url =~ m/$home_page\/(.*).html$/i ) {
                    $original_slug = $1;
                } else {
                    Error::report_error("400", "Invalid update post.", "Original slug/URL/post_id to update is missing.");
                }
            }
        }
    } 

    if ( $in_reply_to and length($in_reply_to) > 9 ) {
        $markup .= "\n\nThis post is a reply to <$in_reply_to>.\n\n";
        $markup .= "<!-- reply_to : " . $in_reply_to . " -->\n";
        
    }


    # $q->http('X-Forwarded-For');
    my $auth_header = $ENV{HTTP_AUTHORIZATION};
    my @token_info = split(/ /, $auth_header);
    my $bearer_token = $token_info[1];


    my $ua = LWP::UserAgent->new();
    $ua->default_header('Authorization', 'Bearer ' . $bearer_token);
    my $resp = $ua->post('https://tokens.indieauth.com/token');
    # $resp->content, $resp->status_line, $resp->is_success, $resp

    if ( $resp->status_line eq "200 OK" ) {
        # token is valid. proceed to create or update the post
      
        if ( $action eq "create" ) { 

            my $location = _create_post($markup);
        
            print header( -type     => 'text/html',
                          -status   => '201 Created',
                          -location => $location,
                        );
        } elsif ( $action eq "update" ) {
            _update_post($markup, $original_slug);

            print header( -type     => 'text/html',
                          -status   => '204 No Content',
                        );

        } else {
            Error::report_error("400", "Invalid 'action' provided: $action.", "Only create and update are supported.");
        }

    } else {
        my $hash_ref;
        $hash_ref->{error} = "invalid_request";
        $hash_ref->{error_description} = $resp->status_line;
        my $json_str = encode_json $hash_ref;
        print CGI::header('application/json', '400 Bad Request');
        print $json_str;
        exit;
    }
}


sub _create_table_of_contents {
    my $str = shift;

    my @headers = ();
    my @loop_data = ();

    if ( @headers = $str =~ m{<!-- header:([1-6]):(.*?) -->}igs ) {
        my $len = @headers;
        for (my $i=0; $i<$len; $i+=2 ) {
            my %hash = ();
            $hash{level}      = $headers[$i];
            $hash{toclink}    = $headers[$i+1];
            $hash{cleantitle} = Utils::clean_title($headers[$i+1]);
            push(@loop_data, \%hash); 
        }
    }

    return @loop_data;    
}


sub _create_post {

    my $original_markup = shift;

    my $hash_ref;
    $hash_ref->{markup} = $original_markup;

    my $markup = Utils::trim_spaces($original_markup);
    if ( !defined($markup) || length($markup) < 1 ) {
        Error::report_error("400", "Invalid post.", "You must enter text.");
    } 

    my $syn_to;
    if ( $markup =~ m|^<!--[\s]*syn_to[\s]*:[\s]*(.+)-->|mi ) {
        $syn_to      = Utils::trim_spaces($1);
        my $target_url = Config::get_value_for("bridgy_target_url_" . $syn_to);
        $markup .= "\n\n<!-- bridghy_target_url_"  . $syn_to . " : " . $target_url . " -->\n";
    }

    my $o = PostTitle->new();
    $o->process_title($markup);
    if ( $o->is_error() ) {
        Error::report_error("400", "Error creating post.", $o->get_error_string());
    } 
    my $title        = $o->get_post_title();
    my $post_type    = $o->get_content_type(); # article or note
    my $slug         = $o->get_slug();
    my $page_data    = Format::extract_css($o->get_after_title_markup());
    my $html         = Format::markup_to_html($page_data->{markup}, $o->get_markup_type(), $slug);
    $html            = Format::create_heading_list($html, $slug);

    undef $hash_ref;

    my $tmp_post = $html;
    $tmp_post           = Utils::remove_html($tmp_post);
    my $post_stats      = Format::calc_reading_time_and_word_count($tmp_post); #returns a hash ref

    my $dt_hash_ref     = Utils::create_datetime_stamp();

    $hash_ref->{html}                   = $html;
    $hash_ref->{title}                  = $title;
    $hash_ref->{slug}                   = $slug;
    $hash_ref->{post_type}              = $post_type;
    $hash_ref->{'created_date'}         = $dt_hash_ref->{date};
    $hash_ref->{'created_time'}         = $dt_hash_ref->{time};
    $hash_ref->{'reading_time'}         = $post_stats->{'reading_time'};
    $hash_ref->{'word_count'}           = $post_stats->{'word_count'};
    $hash_ref->{'author'}               = Config::get_value_for("author_name"); 
    $hash_ref->{'toc'}                  = Format::get_power_command_on_off_setting_for("toc", $markup, 0);
    $hash_ref->{'custom_css'}           = $page_data->{custom_css};

    if ( $hash_ref->{toc} ) {
        my @toc_loop = _create_table_of_contents($hash_ref->{html});
        if ( @toc_loop ) {
            $hash_ref->{'toc_loop'} = \@toc_loop;
        } else {
            $hash_ref->{'toc'} = 0;
        }
    }

    if ( $markup =~ m|^<!--[\s]*slug[\s]*:[\s]*(.+)-->|mi ) {
        $hash_ref->{slug}      = Utils::trim_spaces($1);
    }

    if ( $markup =~ m|^<!--[\s]*template[\s]*:[\s]*(.+)-->|mi ) {
        $hash_ref->{template}      = Utils::trim_spaces($1);
    }

    if ( $markup =~ m|^<!--[\s]*imageheader[\s]*:[\s]*(.+)-->|mi ) {
        $hash_ref->{imageheader}      = Utils::trim_spaces($1);
    }

    if ( $markup =~ m|^<!--[\s]*reply_to[\s]*:[\s]*(.+)-->|mi ) {
        $hash_ref->{reply_to}      = Utils::trim_spaces($1);
    }

    if ( $markup =~ m|^<!--[\s]*syn_to[\s]*:[\s]*(.+)-->|mi ) {
        $hash_ref->{syn_to}      = Utils::trim_spaces($1);
    }

    if ( $markup =~ m|^<!--[\s]*description[\s]*:[\s]*(.+)-->|mi ) {
        $hash_ref->{page_description}      = Utils::trim_spaces($1);
    }

    if ( $markup =~ m|^<!--[\s]*dir[\s]*:[\s]*(.+)-->|mi ) {
        $hash_ref->{dir}      = Utils::trim_spaces($1);
        if ( $hash_ref->{dir} !~ m|^[\w]| ) {  
            Error::report_error("400", "Invalid directory: $hash_ref->{dir}", " - Directory structure must start with alpha-numeric.");
        } 
        chop($hash_ref->{dir}) if $hash_ref->{dir} =~ m|[/]$|;  # remove ending forward slash if it exists
        $hash_ref->{location} = Config::get_value_for("home_page") . "/" . $hash_ref->{dir} . "/" . $hash_ref->{slug} . ".html";
    } else {
        $hash_ref->{location} = Config::get_value_for("home_page") . "/" . $hash_ref->{slug} . ".html";
    }

    if ( !Files::output("create", $hash_ref, $markup) ) {
        Error::report_error("400", "Unable to create files.", "Unknown error.");
    }

    return $hash_ref->{location};
}


sub _update_post {

    my $original_markup = shift;
    my $original_slug   = shift;

    my $hash_ref;
    $hash_ref->{markup} = $original_markup;

    my $markup = Utils::trim_spaces($original_markup);
    if ( !defined($markup) || length($markup) < 1 ) {
        Error::report_error("400", "Invalid post.", "You must enter text.");
    } 

# not for updates
#    my $syn_to;
#    if ( $markup =~ m|^<!--[\s]*syn_to[\s]*:[\s]*(.+)-->|mi ) {
#        $syn_to      = Utils::trim_spaces($1);
#        my $target_url = Config::get_value_for("bridgy_target_url_" . $syn_to);
#        $markup .= "\n\n<!-- bridghy_target_url_"  . $syn_to . " : " . $target_url . " -->\n";
#    }

    my $o = PostTitle->new();
    $o->process_title($markup);
    if ( $o->is_error() ) {
        Error::report_error("400", "Error updating post.", $o->get_error_string());
    } 
    my $title        = $o->get_post_title();
    my $post_type    = $o->get_content_type(); # article or note
    my $slug         = $o->get_slug();
    my $page_data    = Format::extract_css($o->get_after_title_markup());
    my $html         = Format::markup_to_html($page_data->{markup}, $o->get_markup_type(), $slug);
    $html            = Format::create_heading_list($html, $slug);

    undef $hash_ref;

    my $tmp_post = $html;
    $tmp_post           = Utils::remove_html($tmp_post);
    my $post_stats      = Format::calc_reading_time_and_word_count($tmp_post); #returns a hash ref

    my $dt_hash_ref     = Utils::create_datetime_stamp();

    $hash_ref->{html}                   = $html;
    $hash_ref->{title}                  = $title;
    $hash_ref->{slug}                   = $slug;
    $hash_ref->{original_slug}          = $original_slug;
    $hash_ref->{post_id}                = $original_slug;
    $hash_ref->{post_type}              = $post_type;
    $hash_ref->{'created_date'}         = $dt_hash_ref->{date};
    $hash_ref->{'created_time'}         = $dt_hash_ref->{time};
    $hash_ref->{'reading_time'}         = $post_stats->{'reading_time'};
    $hash_ref->{'word_count'}           = $post_stats->{'word_count'};
    $hash_ref->{'author'}               = Config::get_value_for("author_name"); 
    $hash_ref->{'toc'}                  = Format::get_power_command_on_off_setting_for("toc", $markup, 0);
    $hash_ref->{'custom_css'}           = $page_data->{custom_css};

    if ( $hash_ref->{toc} ) {
        my @toc_loop = _create_table_of_contents($hash_ref->{html});
        if ( @toc_loop ) {
            $hash_ref->{'toc_loop'} = \@toc_loop;
        } else {
            $hash_ref->{'toc'} = 0;
        }
    }

    if ( $markup =~ m|^<!--[\s]*slug[\s]*:[\s]*(.+)-->|mi ) {
        $hash_ref->{slug}      = Utils::trim_spaces($1);
    }

    if ( $markup =~ m|^<!--[\s]*template[\s]*:[\s]*(.+)-->|mi ) {
        $hash_ref->{template}      = Utils::trim_spaces($1);
    }

    if ( $markup =~ m|^<!--[\s]*imageheader[\s]*:[\s]*(.+)-->|mi ) {
        $hash_ref->{imageheader}      = Utils::trim_spaces($1);
    }

    if ( $markup =~ m|^<!--[\s]*reply_to[\s]*:[\s]*(.+)-->|mi ) {
        $hash_ref->{reply_to}      = Utils::trim_spaces($1);
    }

    if ( $markup =~ m|^<!--[\s]*syn_to[\s]*:[\s]*(.+)-->|mi ) {
        $hash_ref->{syn_to}      = Utils::trim_spaces($1);
    }

    if ( $markup =~ m|^<!--[\s]*description[\s]*:[\s]*(.+)-->|mi ) {
        $hash_ref->{page_description}      = Utils::trim_spaces($1);
    }

    if ( $markup =~ m|^<!--[\s]*dir[\s]*:[\s]*(.+)-->|mi ) {
        $hash_ref->{dir}      = Utils::trim_spaces($1);
        if ( $hash_ref->{dir} !~ m|^[\w]| ) {  
            Error::report_error("400", "Invalid directory: $hash_ref->{dir}", " - Directory structure must start with alpha-numeric.");
        } 
        chop($hash_ref->{dir}) if $hash_ref->{dir} =~ m|[/]$|;  # remove ending forward slash if it exists
        $hash_ref->{location} = Config::get_value_for("home_page") . "/" . $hash_ref->{dir} . "/" . $hash_ref->{slug} . ".html";
    } else {
        $hash_ref->{location} = Config::get_value_for("home_page") . "/" . $hash_ref->{slug} . ".html";
    }

    if ( !Files::output("update", $hash_ref, $markup) ) {
        Error::report_error("400", "Unable to update files.", "Unknown error.");
    }

    # return $hash_ref->{location};
}

1;


__END__

There was an error making a request to your Micropub endpoint. The error received was: {"error_description":"Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJtZSI6Imh0dHA6XC9cL3dyZW4uc291cG1vZGUuY29tXC8iLCJpc3N1ZWRfYnkiOiJodHRwczpcL1wvdG9rZW5zLmluZGllYXV0aC5jb21cL3Rva2VuIiwiY2xpZW50X2lkIjoiaHR0cHM6XC9cL21pY3JvcHVibGlzaC5uZXQiLCJpc3N1ZWRfYXQiOjE0OTgwMTA5MDEsInNjb3BlIjoicG9zdCIsIm5vbmNlIjoxMDI1MzI5MTkzfQ.rC9MKjW-omV1WIIuIjcL0jfO7rraaHytuxssiQDJ7Nw","error":"invalid_request"}



json post format from a micropub client:

{
  "type": [
    "h-entry"
  ],
  "properties": {
    "content": [
      "# test post 21jun2017"
    ]
  }




for an update from a micropub client:

GET /api/v1/micropub?q=source&url=http%3A%2F%2Fwren.soupmode.com%2Ftest-post-21jun2017-1727.html }


returned json for querying a source. 
 "retrieving the source of a post to display in the updating interface."
https://www.w3.org/TR/micropub/#querying-p-1

$json_str = <<JSONSTR;
{
  "type": ["h-entry"],
  "properties": {
    "published": ["2016-02-21T12:50:53-08:00"],
    "content": ["Hello World"],
    "category": [
      "foo", 
      "bar"
    ]
  }
}
JSONSTR



        my $hash_ref = {
                           "type" => ["h-entry"],
                           "properties" => {
                                               "published" => ["2016-02-21T12:50:53-08:00"],
                                               "content"   => ["Hello World"]
                                           }
                       };

        my $json_str = encode_json $hash_ref;



GET http://wren.soupmode.com/api/v1/micropub?q=source&url=http%3A%2F%2Fwren.soupmode.com%2Ftest-of-querying-the-endpoint-for-the-source-content.html HTTP/1.1
  Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJtZSI6Imh0dHA6XC9cL3dyZW4uc291cG1vZGUuY29tXC8iLCJpc3N1ZWRfYnkiOiJodHRwczpcL1wvdG9rZW5zLmluZGllYXV0aC5jb21cL3Rva2VuIiwiY2xpZW50X2lkIjoiaHR0cHM6XC9cL21pY3JvcHViLnJvY2tzXC8iLCJpc3N1ZWRfYXQiOjE0OTkwODUwOTUsInNjb3BlIjoiY3JlYXRlIHVwZGF0ZSBkZWxldGUgdW5kZWxldGUiLCJub25jZSI6NDgxOTc1ODE2fQ.mkyq88kC3XWDTZeXyANy-aqA9msT6gOfG1V0YgNfb_g
