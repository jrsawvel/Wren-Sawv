package Posts;

use strict;
use warnings;

use API::Create;
use API::Read;
use API::Update;

sub posts {
    my $tmp_hash = shift;

    my $page_num = 0;
    my $q = new CGI;
    $page_num = $q->param("page") if $q->param("page");

    my $request_method = $q->request_method();

    if ( $request_method eq "POST" ) {
        Create::create_post();
    } elsif ( $request_method eq "GET" ) {
        my $post_id;
        my $hash_length = scalar keys $tmp_hash;
        if ( $hash_length > 2 ) {
            for ( my $i=1; $i<$hash_length; $i++ ) {
                $post_id .= $tmp_hash->{$i} . "/";
            } 
            chop($post_id);
        } else {
            $post_id = $tmp_hash->{1};
        }
        Read::get_post($post_id);
    } elsif ( $request_method eq "PUT" ) {
        Update::update_post();
    }

    Error::report_error("400", "Not found", "Invalid request $request_method");  
}

1;


