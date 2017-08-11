package S3;

use strict;
use warnings;
use diagnostics;

# use Amazon::S3;

use vars qw/$OWNER_ID $OWNER_DISPLAYNAME/;


sub copy_to_s3 {
    my $filename = shift;
    my $content  = shift;
    my $type     = shift;
     

    my $aws_access_key_id     = Config::get_value_for("aws_access_key_id");
    my $aws_secret_access_key = Config::get_value_for("aws_secret_access_key");

    my $conn = Amazon::S3->new(
        {   aws_access_key_id     => $aws_access_key_id,
            aws_secret_access_key => $aws_secret_access_key,
            retry                 => 1
        }
    );

    my @buckets = @{$conn->buckets->{buckets} || []};

    my $bucket = $buckets[0];

    $bucket->add_key(
            $filename, $content,
            { content_type =>  $type },
    );

}

1;


# at the moment, assuming only one bucket exists, and it's used to host files from wren.
# if more than one bucket, then a loop would be needed to find which bucket to use.
#foreach my $bucket (@buckets) {
#        print $bucket->bucket . "\t" . $bucket->creation_date . "\n";
#        my @keys = @{$bucket->list_all->{keys} || []};
#            foreach my $key (@keys) {
#            print "$key->{key}\t$key->{size}\t$key->{last_modified}\n";
#        }
#}

