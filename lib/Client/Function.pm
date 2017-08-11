package Function;

use strict;
use warnings;
use diagnostics;

sub do_invalid_function {
    my ($tmp_hash) = @_;
    my $function = $tmp_hash->{0};
    $function = "unknown" if !$function;
    Page->report_error("user", "Client Invalid function: $function", "It's not supported.");
    exit;
}

1;
