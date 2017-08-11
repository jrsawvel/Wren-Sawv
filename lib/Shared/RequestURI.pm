package RequestURI;

use strict;
use warnings;
use diagnostics;

sub get_cgi_params_from_path_info {
#    my @param_names = @_;

    my %params;
    my $path_info = $ENV{REQUEST_URI}; # with nginx confi, using this instead of PATH_INFO

    my @values = ();
    if ( $path_info ) {
        $path_info =~ s/\.html//g; 

        $path_info =~ s/\/api\/v1//g;   # api code

        if ( $path_info =~ m/\/wren\// ) {
            $path_info =~ s/\/wren\///;       # client-side code 
            $path_info = "/" . $path_info; 
        }

        if ( $path_info =~ m/\/\?(.*)$/ ) {
            $path_info =~ s/\/\?$1//;
        }

        if ( $path_info =~ m/\?(.*)$/ ) {
            $path_info =~ s/\?$1//;
        }

        $path_info =~ s/\/// if ( $path_info );
        @values = split(/\//, $path_info);
    }
    my $len = @values;

    for (my $i=0; $i<$len; $i++) {
        $params{$i} = $values[$i];
    }
    return %params;
}

1;
