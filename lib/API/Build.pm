package Build;

use strict;
use warnings;

use HTML::Entities;
use URI::Escape::JavaScript qw(escape unescape);
use API::PostTitle;
use API::Format;
use API::Files;
use API::Auth;
use JSON::PP;
use Shared::Utils;

sub rebuild_html {
    my $hash_ref = shift;

    my $original_markup = $hash_ref->{'markup'};

    my $markup = Utils::trim_spaces($original_markup);
    if ( !defined($markup) || length($markup) < 1 ) {
        Error::report_error("400", "Invalid post.", "You must enter text.");
    } 

    my $formtype = $hash_ref->{'form_type'};
    if ( $formtype and ($formtype eq "ajax") ) {
        $markup = URI::Escape::JavaScript::unescape($markup);
        $markup = HTML::Entities::encode($markup, '^\n\x20-\x25\x27-\x7e');
    } else {
#        $markup = Encode::decode_utf8($markup);
    }
#    $markup = HTML::Entities::encode($markup, '^\n\x20-\x25\x27-\x7e');

    my $o = PostTitle->new();
    $o->process_title($markup);
    if ( $o->is_error() ) {
        Error::report_error("400", "Error creating post.", $o->get_error_string());
    } 
    my $title        = $o->get_post_title();
    my $post_type    = $o->get_content_type(); # article or note
    my $slug         = $o->get_slug();
my $page_data    = Format::extract_css($o->get_after_title_markup());
    # my $html       = Format::markup_to_html($markup, $o->get_markup_type(), $slug);
my $html         = Format::markup_to_html($page_data->{markup}, $o->get_markup_type(), $slug);
    # my $html         = Format::markup_to_html($o->get_after_title_markup(), $o->get_markup_type(), $slug);
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

#    if ( $markup =~ m|<!--[\s]*slug[\s]*:[\s]*(.+?)-->|mi ) {
    if ( $markup =~ m|^<!--[\s]*slug[\s]*:[\s]*(.+)-->|mi ) {
        $hash_ref->{slug}      = Utils::trim_spaces($1);
    }

    if ( $markup =~ m|^<!--[\s]*template[\s]*:[\s]*(.+)-->|mi ) {
        $hash_ref->{template}      = Utils::trim_spaces($1);
    }

    if ( $markup =~ m|^<!--[\s]*imageheader[\s]*:[\s]*(.+)-->|mi ) {
        $hash_ref->{imageheader}      = Utils::trim_spaces($1);
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
    }

    $hash_ref->{status}      = 200;
    $hash_ref->{description} = "OK";

    return $hash_ref;

#    my $json_str = encode_json $hash_ref;
#    print CGI::header('application/json', '200 Accepted');
#    print $json_str;
#    exit;
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

1;

