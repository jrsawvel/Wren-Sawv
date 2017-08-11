package Utils;

use strict;
use warnings;

use Time::Local;

sub create_datetime_stamp {
    my $minutes_to_add = shift;

    # creates string for DATETIME field in database as
    # YYYY-MM-DD HH:MM:SS    (24 hour time)
    # Date and time is GMT not local.

    if ( !$minutes_to_add ) {
        $minutes_to_add = 0;
    }

#  2016/01/25 17:04:47 
#    my $epochsecs = time() + ($minutes_to_add * 60);
#    my ($sec, $min, $hr, $mday, $mon, $yr)  = (gmtime($epochsecs))[0,1,2,3,4,5];
#    my $datetime = sprintf "%04d/%02d/%02d %02d:%02d:%02d", 2000 + $yr-100, $mon+1, $mday, $hr, $min, $sec;


    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @dow = qw(Sun Mon Tue Wed Thu Fri Sat);

# Mon, 25 Jan 2016 05:28:04 GMT
    my $epochsecs = time() + ($minutes_to_add * 60);
    my ($sec, $min, $hr, $mday, $mon, $yr, $wday)  = (gmtime($epochsecs))[0,1,2,3,4,5,6];
    # my $datetime = sprintf "%s, %02d %s %04d %02d:%02d:%02d GMT", $dow[$wday], $mday, $months[$mon], 1900 + $yr, $hr, $min, $sec;
    # return $datetime;

    my $hash_ref;
    $hash_ref->{date} = sprintf "%s, %02d %s %04d",  $dow[$wday], $mday, $months[$mon], 1900 + $yr;
    $hash_ref->{time} = sprintf "%02d:%02d:%02d Z",  $hr, $min, $sec;
    
    return $hash_ref;

}

sub create_random_string {
    my @chars = ("A".."Z", "a".."z", "0" .. "9");
    my $string;
    $string .= $chars[rand @chars] for 1..8;
    return $string;
}

sub trim_spaces {
    my $str = shift;
    if ( !defined($str) ) {
        return "";
    }
    # remove leading spaces.   
    $str  =~ s/^\s+//;
    # remove trailing spaces.
    $str  =~ s/\s+$//;
    return $str;
}

# todo is this used? What about a perl module?
sub url_encode {
    my $text = shift;
    $text =~ s/([^a-z0-9_.!~*'() -])/sprintf "%%%02X", ord($1)/eig;
    $text =~ tr/ /+/;
    return $text;
}

# todo is this needed?
sub url_decode {
    my $text = shift;
    $text =~ tr/\+/ /;
    $text =~ s/%([a-f0-9][a-f0-9])/chr( hex( $1 ) )/eig;
    return $text;
}

sub url_to_link {
    my $str_orig = shift;
    # from Greymatter
    # two lines of code written in part by Neal Coffey (cray@indecisions.org)
    $str_orig =~ s#(^|\s)(\w+://)([A-Za-z0-9?=:\|;,_\-/.%+&'~\(\)\#@!\^]+)#$1<a href="$2$3">$2$3</a>#isg;
        $str_orig =~ s#(^|\s)(www.[A-Za-z0-9?=:\|;,_\-/.%+&'~\(\)\#@!\^]+)#$1<a href="http://$2">$2</a>#isg;

    # next line a modification from jr to accomadate e-mail links created with anchor tag
    $str_orig =~ s/(^|\s)(\w+\@\w+\.\w+)/<a href="mailto:$2">$1$2<\/a>/isg;
    return $str_orig;
}

sub br_to_newline {
    my $str = shift;
    $str =~ s/<br \/>/\r\n/g;
    return $str;
}

sub remove_html {
    my $str = shift;
    # remove ALL html
    $str =~ s/<([^>])+>|&([^;])+;//gsx;
    return $str;
}

sub newline_to_br {
    my $str = shift;
    $str =~ s/[\r][\n]/<br \/>/g;
    $str =~ s/[\n]/<br \/>/g;
    return $str;
}

sub remove_newline {
    my $str = shift;
#    $str =~ s/[\r][\n]//gs;
#    $str =~ s/\n.*//s;
#    $str =~ s/\s.*//s;
    $str =~ s/\n/ /gs;
    return $str;
}

sub is_numeric {
    my $str = shift;
    my $rc = 0;
    return $rc if !$str;
    if ( $str =~ m|^[0-9]+$| ) {
        $rc = 1;
    }
    return $rc;
}

sub is_float {
    my $str = shift;
    my $rc = 0;
    if ( $str =~ m|^[0-9\.]+$| ) {
        $rc = 1;
    }
    return $rc;
}

sub trim_br {
    my $str = shift;
    # remove leading <br />
    $str =~ s|^(<br />)+||g;
    # remove trailing br 
    $str =~ s|(<br />)+$||g;
    return $str;
}

sub round {
    my $number = shift;
    return int($number + .5 * ($number <=> 0));
}

# http://stackoverflow.com/questions/77226/how-can-i-capitalize-the-first-letter-of-each-word-in-a-string-in-perl
sub ucfirst_each_word {
    my $str = shift;
    $str =~ s/(\w+)/\u$1/g;
    return $str;
}
    
sub is_valid_email {
  my $mail = shift;                                                  #in form name@host
  return 0 if ( $mail !~ /^[0-9a-zA-Z\.\-\_]+\@[0-9a-zA-Z\.\-]+$/ ); #characters allowed on name: 0-9a-Z-._ on host: 0-9a-Z-. on between: @
  return 0 if ( $mail =~ /^[^0-9a-zA-Z]|[^0-9a-zA-Z]$/);             #must start or end with alpha or num
  return 0 if ( $mail !~ /([0-9a-zA-Z]{1})\@./ );                    #name must end with alpha or num
  return 0 if ( $mail !~ /.\@([0-9a-zA-Z]{1})/ );                    #host must start with alpha or num
  return 0 if ( $mail =~ /.\.\-.|.\-\..|.\.\..|.\-\-./g );           #pair .- or -. or -- or .. not allowed
  return 0 if ( $mail =~ /.\.\_.|.\-\_.|.\_\..|.\_\-.|.\_\_./g );    #pair ._ or -_ or _. or _- or __ not allowed
  return 0 if ( $mail !~ /\.([a-zA-Z]{2,3})$/ );                     #host must end with '.' plus 2 or 3 alpha for TopLevelDomain (MUST be modified in future!)
  return 1;
}

sub clean_title {
        my $str = shift;
        $str =~ s|[-]||g;
        $str =~ s|[ ]|-|g;
        $str =~ s|[:]|-|g;
        $str =~ s|--|-|g;
        # only use alphanumeric, underscore, and dash in friendly link url
        $str =~ s|[^\w-]+||g;
        return lc($str);
}
   
sub shuffle_array {
    my $array = shift;
    my $i;
    for ($i = @$array; --$i; ) {
        my $j = int rand ($i+1);
        next if $i == $j;
        @$array[$i, $j] = @$array[$j,$i];
    }
}

sub quote_string {
    my $str = shift;
    return "NULL" unless defined $str;
    $str =~ s/'/''/g;
    return "'$str'";
}

sub format_date_time{
    my $orig_dt = shift;

    my @tmp_array = split(/ /, $orig_dt);

    my $date = $tmp_array[0];
    my $time = $tmp_array[1];

    my @date_array = split(/\//, $date);

    my %hash = ();
 
    my @short_month_names = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    
    my $formatted_dt = sprintf "%s %d, %d %s Z", $short_month_names[$date_array[1]-1], $date_array[2], $date_array[0], $time;

    return $formatted_dt;
}

# receives date string as: YYYY-MM-DD HH-MM-SS
# date format used in database date field
# code from: http://stackoverflow.com/users/4234/dreeves
# in post: http://stackoverflow.com/questions/95492/how-do-i-convert-a-date-time-to-epoch-time-aka-unix-time-seconds-since-1970
# I changed timelocal to timegm
sub convert_date_to_epoch {
  my($s) = @_;
  my($year, $month, $day, $hour, $minute, $second);

  if($s =~ m{^\s*(\d{1,4})\W*0*(\d{1,2})\W*0*(\d{1,2})\W*0*
                 (\d{0,2})\W*0*(\d{0,2})\W*0*(\d{0,2})}x) {
    $year = $1;  $month = $2;   $day = $3;
    $hour = $4;  $minute = $5;  $second = $6;
    $hour |= 0;  $minute |= 0;  $second |= 0;  # defaults.
    $year = ($year<100 ? ($year<70 ? 2000+$year : 1900+$year) : $year);
    return timegm($second,$minute,$hour,$day,$month-1,$year);  
  }
  return -1;

}

sub modify_date {
    my $date_str = shift; # Mon, 22 Feb 2016
    my @arr = split / /, $date_str;
    return "$arr[2] $arr[1], $arr[3]";
}

# my original date-time format:
#    Mon, 05 Jun 2017 16:44:12 Z
# needs to be:
#    2017-06-05T11:07:30+00:00
# or 2017-06-05T16:32:53Z
#
# per https://www.ietf.org/rfc/rfc3339.txt
# and https://en.wikipedia.org/wiki/ISO_8601

sub convert_date_time_to_iso8601_format {

    my $orig_dt = shift; # example: Mon, 05 Jun 2017 16:44:12 Z

    my $month_names = {
        "Jan" => "01",
        "Feb" => "02",
        "Mar" => "03",
        "Apr" => "04",
        "May" => "05",
        "Jun" => "06",
        "Jul" => "07",
        "Aug" => "08",
        "Sep" => "09",
        "Oct" => "10",
        "Nov" => "11",
        "Dec" => "12"
    };

    my @tmp_array = split(/ /, $orig_dt);

    my $day      = $tmp_array[1];
    my $monname  = $tmp_array[2]; # ex: Jan
    my $year     = $tmp_array[3];
    my $time     = $tmp_array[4];

    return "$year-$month_names->{$monname}-$day" . "T" . $time . "Z"; 
}

1;
