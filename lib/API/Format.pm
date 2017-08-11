package Format;

use strict;
use warnings;

use Text::Textile;
use Text::MultiMarkdownWren;
use LWP::Simple;
use HTML::TokeParser;


# <!-- toc:yes -->
sub get_power_command_on_off_setting_for {
    my ($command, $str, $default_value) = @_;

    my $binary_value = $default_value;   # default value should come from config file
    
# if ( $str =~ m|^<!--[\s]*$command[\s]*:[\s]*(.*?)-->$|mi ) {
    if ( $str =~ m|^<!--[\s]*$command[\s]*:[\s]*(.*?)-->|mi ) {
        my $string_value = Utils::trim_spaces(lc($1));
        if ( $string_value eq "no" ) {
            $binary_value = 0;
        } elsif ( $string_value eq "yes" ) {
            $binary_value = 1;
        }
    }
    return $binary_value;
}

sub custom_commands {
    my $formattedcontent = shift;
    my $postid = shift;

    $formattedcontent =~ s/^br[.]/<br \/>/igm;

    $formattedcontent =~ s/^fence[.][.]/<\/code><\/pre><\/div>/igm;
    $formattedcontent =~ s/^fence[.]/<div class="fenceClass"><pre><code>/igm;


    # 17mar2017 - added the three backtick support
    # hat tip to the regex in this answer: 
    # http://unix.stackexchange.com/questions/61139/extract-triple-backtick-fenced-code-block-excerpts-from-markdown-file

    my $ctr = 0;

#    while ( $formattedcontent =~ /(^`{3,}\s*\n)/msg ) {
    while ( $formattedcontent =~ /(^`{3,}\s*)/mg ) {
        if ( !$ctr ) {
            $formattedcontent =~ s/```/<pre><code>/;
            $ctr = 1;
        } elsif ( $ctr ) {
            $formattedcontent =~ s/```/<\/code><\/pre>/;
            $ctr = 0;
        }
    }

    return $formattedcontent;
}

sub markup_to_html {
    my $markup      = shift;
    my $markup_type = shift;
    my $slug        = shift;

    if ( get_power_command_on_off_setting_for("markdown", $markup, 0) ) {
        $markup_type = "markdown";
    }


#    my $html = remove_power_commands($markup);

#    $html = remove_slug_command($html); 

    my $html = $markup;

    my $newline_to_br = 1;
    $newline_to_br    = 0 if !get_power_command_on_off_setting_for("newline_to_br", $markup, 1);

    $html = Utils::url_to_link($html) if get_power_command_on_off_setting_for("url_to_link", $markup, 0);

    $html = custom_commands($html); 

    if ( $markup_type eq "markdown" ) {
        my $md   = Text::MultiMarkdownWren->new;
        $html = $md->markdown($html, {newline_to_br => $newline_to_br, heading_ids => 0}  );
    } elsif ( $markup_type eq "textile" ) {
        my $textile = new Text::Textile;
        $html = $textile->process($html);
    }

# testing on 18apr2017
#    $html =~ s/\[div/<div/igm;

    # why do this?
    $html =~ s/&#39;/'/sg;

    return $html;
}

sub calc_reading_time_and_word_count {
    my $post = shift; # html already removed
    my $hash_ref;
    my @tmp_arr                 = split(/\s+/s, $post);
    $hash_ref->{'word_count'}   = scalar (@tmp_arr);
    $hash_ref->{'reading_time'} = 0; #minutes
    $hash_ref->{'reading_time'} = int($hash_ref->{'word_count'} / 180) if $hash_ref->{'word_count'} >= 180;
    return $hash_ref;
}


sub create_heading_list {
    my $str  = shift;
    my $slug = shift;

    my @headers = ();
    my $header_list = "";

#    if ( @headers = $str =~ m{\s+<h([1-6]).*?>(.*?)</h[1-6]>}igs ) {
    if ( @headers = $str =~ m{<h([1-6]).*?>(.*?)</h[1-6]>}igs ) {
        my $len = @headers;
        for (my $i=0; $i<$len; $i+=2) { 
            my $heading_text = Utils::remove_html($headers[$i+1]); 
            my $heading_url  = Utils::clean_title($heading_text);
            my $oldstr = "<h$headers[$i]>$headers[$i+1]</h$headers[$i]>";
            # mar 3, 2017 change below
            # $newstr = "<a name=\"$heading_url\"></a>\n<h$headers[$i]>$headers[$i+1]</h$headers[$i]>";
            my $newstr = "<h$headers[$i]><a id=\"$heading_url\"></a>$headers[$i+1]</h$headers[$i]>";
            $str =~ s/\Q$oldstr/$newstr/i;
            $header_list .= "<!-- header:$headers[$i]:$heading_text -->\n";   
        } 
    }

    $str .= "\n$header_list";  

    return $str; 
}

sub extract_css {
    my $str = shift;

# <!-- css_start
#
# css_end -->

    my $return_data; 

#    $str =~ s/^css[.][.]/<\/css>/igm;
#    $str =~ s/^css[.]/<css>/igm;

    $str =~ s/^css_end -->/<\/css>/igm;
    $str =~ s/^<!-- css_start/<css>/igm;

    if ( $str =~ m/^(.*?)<css>(.*?)<\/css>(.*?)$/is ) {
        $return_data->{markup} = $1 . $3;
        $return_data->{custom_css}    = $2;
    } else {
        $return_data->{markup} = $str;
        $return_data->{custom_css} = "";
    }

    return $return_data;
}

1;

