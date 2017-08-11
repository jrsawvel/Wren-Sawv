package Config;

use strict;
use warnings;
use diagnostics;

use YAML::Tiny;

my $yml_file = "/home/sawv/Wren/yaml/wren.yml";
my $yaml     = YAML::Tiny->new;
$yaml        = YAML::Tiny->read($yml_file);

sub get_value_for {
    my $name = shift;
    return 0 if !exists($yaml->[0]->{$name}); 
    return $yaml->[0]->{$name};
}

sub set_value_for {
    my $name = shift;
    my $value = shift;
    return 0 if !exists($yaml->[0]->{$name});
    $yaml->[0]->{$name} = $value;
    return 1;
}

1;

