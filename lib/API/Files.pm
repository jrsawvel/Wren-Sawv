package Files;

use strict;
use warnings;
use diagnostics;

use Storable 'dclone';
use LWP::Simple;
use Time::Local;
use File::Path qw(make_path remove_tree);
use JSON::PP;
use HTML::Entities;
use API::Error;
# use API::S3;
use API::Webmentions;


sub output {
    my $submit_type = shift;
    my $hash_ref    = shift;
    my $markup      = shift;

    my $t;

    if ( exists($hash_ref->{template}) ) {
        $t = Page->new($hash_ref->{template});
    } elsif ( $hash_ref->{post_type} eq "article" ) {
        $t = Page->new("articlehtml");
    } else {
        $t = Page->new("notehtml");
    }
       
    my $html = $hash_ref->{html};

    $t->set_template_variable("html", $html);
    $t->set_template_variable("title", $hash_ref->{title});
  
    if ( exists($hash_ref->{imageheader}) ) {
        $t->set_template_variable("imageheader", $hash_ref->{imageheader});
    }

    if ( exists($hash_ref->{description}) ) {
        $t->set_template_variable("description", $hash_ref->{description});
    }

    if ( $hash_ref->{toc} ) {
        $t->set_template_variable("usingtoc", "1");
        $t->set_template_loop_data("toc_loop", $hash_ref->{toc_loop});
    } else {
        $t->set_template_variable("usingtoc", "0");
    }

    if ( exists($hash_ref->{custom_css}) ) {
        $t->set_template_variable("using_custom_css", "1");
        $t->set_template_variable("custom_css", $hash_ref->{custom_css});
    } 

    my $html_output  = $t->create_html_page($hash_ref->{title});

    if ( $submit_type eq "update" and $hash_ref->{micropub} ne "yes" ) {
        $hash_ref->{slug} = $hash_ref->{original_slug};
    } 

    if ( $submit_type eq "rebuild" ) {
        _save_html($html_output, $hash_ref);
        return 1;
    }
        
    if ( $submit_type eq "webmention" ) {
        _save_html($html_output, $hash_ref);
        _copy_to_s3_bucket($hash_ref, $markup, $html_output);
        return 1;
    }
        
    _save_markup_to_storage_directory($submit_type, $markup, $hash_ref);

    _save_markup_to_backup_directory($submit_type, $markup, $hash_ref) if $submit_type eq "update";

    _save_markup_to_web_directory($submit_type, $markup, $hash_ref);

    _save_html($html_output, $hash_ref);

    if ( $submit_type eq "create" ) {
       my $stream = _update_json_file($hash_ref); 
       _create_rss_file($hash_ref, $stream);
       _create_microformatted_file($hash_ref, $stream);
#       _create_sitemap_file($stream);
    }

    _copy_to_s3_bucket($hash_ref, $markup, $html_output);

    if ( $submit_type eq "create" and exists($hash_ref->{reply_to}) ) {
        # source url (reply) and target url (post replying to)
        Webmentions::send_webmention($hash_ref->{location}, $hash_ref->{reply_to});
    }

    if ( $submit_type eq "create" and exists($hash_ref->{syn_to}) ) {
        Webmentions::send_webmention_to_bridgy($hash_ref->{location}, $hash_ref->{syn_to});
    }

    return 1;
}

sub _save_markup_to_storage_directory {
    my $submit_type = shift;
    my $markup   = shift;
    my $hash_ref = shift;

    my $save_markup = $markup .  "\n\n<!-- author_name: " . Config::get_value_for("author_name") . " -->\n<!-- published_date: $hash_ref->{created_date} -->\n<!-- published_time: $hash_ref->{created_time} -->\n";

    my $tmp_slug = $hash_ref->{slug};

    if ( exists($hash_ref->{dir}) ) {
        # 2oct2016 commented out because unnecessary since markup would already contain the exact same dir command
        # $save_markup .=  "<!-- dir : $hash_ref->{dir} -->\n";
        $tmp_slug = Utils::clean_title($hash_ref->{dir}) . "-" . $tmp_slug;
    }

    # write markup to markup storage outside of document root
    # if "create" then the file must not exist
    my $domain_name = Config::get_value_for("domain_name");
    my $markup_filename = Config::get_value_for("markup_storage") . "/" . $domain_name . "-" . $tmp_slug . ".markup";  

    if ( $submit_type eq "create" and  -e $markup_filename ) {
        Error::report_error("400", "Unable to create markup and HTML files because they already exist.", "Change title or do an 'update'.");
    }

    if ( $markup_filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $markup_filename = $1;
    } else {
        Error::report_error("500", "Bad file name.", "Could not write markup for post id: $hash_ref->{title} filename: $markup_filename");
    }
    open FILE, ">$markup_filename" or Error::report_error("500", "Unable to open file for write.", "Post id: $hash_ref->{slug} filename: $markup_filename");
    print FILE $save_markup . "\n";
    close FILE;
}

sub _save_markup_to_backup_directory {
    my $submit_type = shift;
    my $markup   = shift;
    my $hash_ref = shift;

    my $tmp_post_id = $hash_ref->{slug};
    my $tmp_slug    = $hash_ref->{slug};

    if ( exists($hash_ref->{dir}) ) {
        $tmp_post_id = $hash_ref->{dir} . "/" . $hash_ref->{slug}; 
        $tmp_slug = Utils::clean_title($hash_ref->{dir}) . "-" . $tmp_slug;
    } 

    my $previous_markup_version = read_markup_file($tmp_post_id);
    my $epoch_secs = time();
    my $markup_filename = Config::get_value_for("versions_storage") . "/" . $tmp_slug . "-" . $epoch_secs . "-version.txt";  
    if ( $markup_filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $markup_filename = $1;
    } else {
        Error::report_error("500", "Bad file name.", "Could not write markup for post id: $hash_ref->{title} filename: $markup_filename");
    }
    open FILE, ">$markup_filename" or Error::report_error("500", "Unable to open file for write.", "Post id: $hash_ref->{slug} filename: $markup_filename");
    print FILE $previous_markup_version . "\n";
    close FILE;
}

sub _save_markup_to_web_directory {
    my $submit_type = shift;
    my $markup   = shift;
    my $hash_ref = shift;

    my $markup_filename;

    if ( exists($hash_ref->{dir}) ) {
        my $dir_path = Config::get_value_for("default_doc_root") . "/" . $hash_ref->{dir};
        if ( $dir_path =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
            $dir_path = $1;
            make_path( $dir_path, {error => \my $err} );
            if (@$err) {
                Error::report_error("500", "Bad directory path.", "Could not create directory structure.");
            }
            $markup_filename = Config::get_value_for("default_doc_root") . "/" . $hash_ref->{dir} . "/" . $hash_ref->{slug} . ".txt";  
        }
    } else {
        $markup_filename = Config::get_value_for("default_doc_root") . "/" . $hash_ref->{slug} . ".txt";  
    }

    if ( $markup_filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $markup_filename = $1;
    } else {
        Error::report_error("500", "Bad file name.", "Could not write markup for post id: $hash_ref->{title} filename: $markup_filename");
    }
    open FILE, ">$markup_filename" or Error::report_error("500", "Unable to open file for write.", "Post id: $hash_ref->{slug} filename: $markup_filename");
    print FILE $markup . "\n";
    close FILE;
}

sub _save_html {
    my $html = shift;
    my $hash_ref = shift;

    my $html_filename;

    if ( exists($hash_ref->{dir}) ) {
        my $dir_path = Config::get_value_for("default_doc_root") . "/" . $hash_ref->{dir};
        if ( $dir_path =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
            $dir_path = $1;
            make_path( $dir_path, {error => \my $err} );
            if (@$err) {
                Error::report_error("500", "Bad directory path.", "Could not create directory structure.");
            }
            $html_filename = Config::get_value_for("default_doc_root") . "/" . $hash_ref->{dir} . "/" . $hash_ref->{slug} . ".html";  
        }
    } else {
        $html_filename = Config::get_value_for("default_doc_root") . "/" . $hash_ref->{slug} . ".html";  
    }

    if ( $html_filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $html_filename = $1;
    } else {
        Error::report_error("500", "Bad file name.", "Could not write html for post id: $hash_ref->{title} filename: $html_filename");
    }
    open FILE, ">$html_filename" or Error::report_error("500", "Unable to open file for write.", "Post id: $hash_ref->{slug} filename: $html_filename");
    print FILE $html . "\n";
    close FILE;
}


sub read_markup_file {
    my $post_id = shift;

    my $markup;

    my $markup_filename = Config::get_value_for("default_doc_root") . "/" . $post_id . ".txt";  

    if ( -e $markup_filename ) {
        open(my $fh, "<", $markup_filename ) or Error::report_error("400", "Could not open $post_id.txt for read.", $!);
        while ( <$fh> ) {
            # chomp;
            $markup .= $_; 
        }
        close($fh) or Error::report_error("400", "Could not close $post_id.txt after reading.", $!);
    } else {
        Error::report_error("400", "[1] Could not read $post_id.txt.", "File not found.");
    }

    return $markup;
}

sub _update_json_file {
    my $hash_ref = shift;

    # my $filename = Config::get_value_for("default_doc_root") . "/" . Config::get_value_for("links_json_file");
    my $filename = Config::get_value_for("private_dir") . "/" . Config::get_value_for("links_json_file");

    my $json_text;
 
    if ( -e $filename ) {
        open(my $fh, "<", $filename ) or Error::report_error("400", "Could not open links JSON file for read.", $!);
        while ( <$fh> ) {
            chomp;
            $json_text .= $_; 
        }
        close($fh) or Error::report_error("400", "Could not close links JSON file after reading.", $!);
    } else {
        Error::report_error("400", "[2] Could not read links JSON file.", "File not found.");
    }

    my $perl_hash = decode_json $json_text;
    my $stream    = $perl_hash->{posts};

    my $tmp_hash;
    $tmp_hash->{title} = $hash_ref->{title};
    $tmp_hash->{pubDate} = "$hash_ref->{created_date} $hash_ref->{created_time}";
    if ( exists($hash_ref->{dir}) ) {
        $tmp_hash->{link} = Config::get_value_for("home_page") . "/" . $hash_ref->{dir} . "/" . $hash_ref->{slug} . ".html";
    } else {
        $tmp_hash->{link} = Config::get_value_for("home_page") . "/" . $hash_ref->{slug} . ".html";
    }
    $tmp_hash->{author} = Config::get_value_for("author_name");

    unshift @$stream, $tmp_hash; 

    $perl_hash->{posts} = $stream;


#   $json_text = JSON::encode_json $perl_hash;
    my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref; 

    $json_text = $json_obj->pretty->encode($perl_hash);


    # write links json file
    if ( $filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $filename = $1;
    } else {
        Error::report_error("500", "Bad file name.", "Could not write links JSON file. $!");
    }
    open FILE, ">$filename" or Error::report_error("500", "Unable to open links JSON file for write.", $!);
    print FILE $json_text . "\n";
    close FILE;


    return $stream; 
}


sub _create_rss_file {
    my $hash_ref = shift;
    my $stream = shift; # referecne to an array of hashes

    my $stream_len = @$stream;

    my $max_str_len = 250;

    my $max_entries = Config::get_value_for("max_entries");

    my @rss_stream = ();
    for ( my $i=0; $i<$max_entries and $i<$stream_len; $i++ ) {
#        my $tmp_hash_ref = dclone $stream->[$i];
        my $tmp_hash_ref = $stream->[$i];
        my $web_page = get($tmp_hash_ref->{link});
        if ( !$web_page ) {
            next;
        } else {
            $tmp_hash_ref->{description} = $tmp_hash_ref->{title};
            foreach my $match ($web_page =~ m/<p>(.*?)<\/p>/gs) {
                if ( $match =~ m/^[\w]/ ) {
                    $match =~ s/<([^>])+>|&([^;])+;//gsx;   # remove html
                    $match = Utils::trim_spaces($match);
                    if ( length($match) > $max_str_len ) {
                        $match = substr $match, 0, $max_str_len - 4;
                        $match .= " ...";
                        $tmp_hash_ref->{description} = $match;
                    } elsif ( length($match) < 0 ) {
                        $tmp_hash_ref->{description} = $tmp_hash_ref->{title};
                    } else {
                        $tmp_hash_ref->{description} = $match;
                    }
                    last;
                } else {
                    next;
                }
            }
        }
        delete($tmp_hash_ref->{author});
        $tmp_hash_ref->{title}  = HTML::Entities::encode_entities_numeric($tmp_hash_ref->{title}, '&');
        push(@rss_stream, $tmp_hash_ref);
    } 

    # my $max_entries = Config::get_value_for("max_entries");
    # my @rss_stream = ();
    # for ( my $i=0; $i<$max_entries and $i<$stream_len; $i++ ) {
    #    push(@rss_stream, $stream->[$i]);
    # } 

    my $t = Page->new("rss");
    $t->set_template_variable("site_name",         Config::get_value_for("site_name"));
    $t->set_template_variable("link",              Config::get_value_for("home_page")); 
    $t->set_template_variable("site_description",  Config::get_value_for("site_description"));
    $t->set_template_variable("app_name",          Config::get_value_for("app_name"));
    $t->set_template_variable("current_date_time", "$hash_ref->{created_date} $hash_ref->{created_time}");
    $t->set_template_loop_data("article_loop", \@rss_stream);
    my $rss_output  = $t->create_file();

    # write rss to file
    my $rss_filename = Config::get_value_for("default_doc_root") . "/" . Config::get_value_for("rss_file");
    if ( $rss_filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $rss_filename = $1;
    } else {
        Error::report_error("500", "Bad file name.", "Could not write RSS file. $!");
    }
    open FILE, ">$rss_filename" or Error::report_error("500", "Unable to open RSS file for write.", "$!");
    print FILE $rss_output . "\n";
    close FILE;

# commented out on 09aug2017
#    S3::copy_to_s3(Config::get_value_for("rss_file"),  $rss_output, "text/xml");

    


    my $author_name = Config::get_value_for("author_name");


    ############## create JSON feed file

    my $json_hash_ref;

    $json_hash_ref->{version}        =  "https://jsonfeed.org/version/1";
    $json_hash_ref->{title}          =  Config::get_value_for("site_name");
    $json_hash_ref->{home_page_url}  =  Config::get_value_for("home_page"); 
    $json_hash_ref->{feed_url}       =  Config::get_value_for("home_page") . "/feed.json";
    $json_hash_ref->{description}    =  Config::get_value_for("site_name") . " " . Config::get_value_for("site_description");
#    $json_hash_ref->{pubDate}        =  $hash_ref->{created_date} . " " . $hash_ref->{created_time};
#    $json_hash_ref->{generator}      =  Config::get_value_for("app_name");

    my @items = ();


# my $jan2018_ctr = 0;

    foreach my $hr ( @rss_stream ) {
        my $h;
        $h->{id}              =  $hr->{link};     
        $h->{url}             =  $hr->{link};     
        $h->{title}           =  $hr->{title};     
        $h->{author}          =  { "name" => $author_name };
        $h->{date_published}  =  Utils::convert_date_time_to_iso8601_format($hr->{pubDate});     
        $h->{content_text}    =  $hr->{description};     
        push(@items, $h);
        
#        $jan2018_ctr++;
#        if ( $jan2018_ctr >= 5 ) {
#            last;
#        }
    }
    $json_hash_ref->{items}       = \@items;
    my $json_obj = JSON::PP->new->ascii->pretty;
    my $json_str = $json_obj->encode($json_hash_ref);

    # write json feed to file
    my $json_feed_filename = Config::get_value_for("default_doc_root") . "/" . Config::get_value_for("json_feed_file");
    if ( $json_feed_filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $json_feed_filename = $1;
    } else {
        Error::report_error("500", "Bad file name.", "Could not write JSON feed file. $!");
    }
    open FILE, ">$json_feed_filename" or Error::report_error("500", "Unable to open JSON feed file for write.", "$!");
    print FILE $json_str . "\n";
    close FILE;

# commented out on 09aug2017
#    S3::copy_to_s3(Config::get_value_for("json_feed_file"),  $json_str, "application/json");
}


sub _create_sitemap_file {
    my $stream = shift;

    my @links = ();

    foreach my $hash_ref ( @$stream ) {
        delete($hash_ref->{title});
        delete($hash_ref->{pubDate});
        delete($hash_ref->{author});
        delete($hash_ref->{description});
        push(@links, $hash_ref);
    }

    my $t = Page->new("sitemap");
    $t->set_template_loop_data("link_loop", \@links);
    my $sitemap_output  = $t->create_file();

    # write sitempa to file
    # my $sitemap_filename = Config::get_value_for("default_doc_root") . "/" . Config::get_value_for("sitemap_file");
    my $sitemap_filename = Config::get_value_for("private_dir") . "/" . Config::get_value_for("sitemap_file");
    if ( $sitemap_filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $sitemap_filename = $1;
    } else {
        Error::report_error("500", "Bad file name.", "Could not write sitemap file. $!");
    }
    open FILE, ">$sitemap_filename" or Error::report_error("500", "Unable to open sitemap file for write.", "$!");
    print FILE $sitemap_output . "\n";
    close FILE;

#    S3::copy_to_s3(Config::get_value_for("sitemap_file"),  $sitemap_output, "text/xml");
}


sub _create_microformatted_file {
    my $hash_ref = shift;
    my $stream = shift;

    my $author_name = Config::get_value_for("author_name");

    my $stream_len = @$stream;

    my $max_entries = Config::get_value_for("max_entries");
    my @mft_stream = ();
    for ( my $i=0; $i<$max_entries and $i<$stream_len; $i++ ) {
        delete($stream->[$i]->{comma});
        $stream->[$i]->{author} = $author_name;
        push(@mft_stream, $stream->[$i]);
    } 

    my $t = Page->new("mft");

    $t->set_template_variable("site_name",         Config::get_value_for("site_name"));
    $t->set_template_variable("site_description",  Config::get_value_for("site_description"));

    $t->set_template_loop_data("article_loop", \@mft_stream);
    my $mft_output  = $t->create_html_page("Microformatted Homepage of Article Links");

    # write microformattted content to file
    my $mft_filename = Config::get_value_for("default_doc_root") . "/" . Config::get_value_for("mft_file");
    if ( $mft_filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $mft_filename = $1;
    } else {
        Error::report_error("500", "Bad file name.", "Could not write microformatted file. $!");
    }
    open FILE, ">$mft_filename" or Error::report_error("500", "Unable to open microformatted file for write.", "$!");
    print FILE $mft_output . "\n";
    close FILE;

# commented out on 09aug2017
#    S3::copy_to_s3(Config::get_value_for("mft_file"),  $mft_output, "text/html");
}

sub _copy_to_s3_bucket {
    my $hash_ref = shift;
    my $markup   = shift;
    my $html     = shift;

    my $relative_txt_file;
    my $relative_html_file;

    if ( exists($hash_ref->{dir}) ) {
        $relative_txt_file =  $hash_ref->{dir} . "/" . $hash_ref->{slug} . ".txt"; 
        $relative_html_file =  $hash_ref->{dir} . "/" . $hash_ref->{slug} . ".html"; 
    } else {
        $relative_txt_file =  $hash_ref->{slug} . ".txt"; 
        $relative_html_file =  $hash_ref->{slug} . ".html"; 
    }

# commented out on 09aug2017
#    S3::copy_to_s3($relative_txt_file,  $markup, "text/plain");
#    S3::copy_to_s3($relative_html_file, $html,   "text/html");
}


1;
