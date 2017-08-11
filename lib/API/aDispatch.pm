package aDispatch;

use strict;
use warnings;

use API::aModules;
use Shared::RequestURI;

my %cgi_params = RequestURI::get_cgi_params_from_path_info();

my $dispatch_for = {
    posts              =>   sub { return \&do_sub(       "Posts",       "posts"                    ) },
    users              =>   sub { return \&do_sub(       "Users",       "users"                    ) },
    searches           =>   sub { return \&do_sub(       "Searches",    "searches"                 ) },
    webmentions        =>   sub { return \&do_sub(       "Webmentions", "webmentions"              ) },
    showerror          =>   sub { return \&do_sub(       "Error",       "error"                    ) },
    micropub           =>   sub { return \&do_sub(       "Micropub",    "micropub"                 ) },
};

sub execute {
    my $function = $cgi_params{0};
    $dispatch_for->{showerror}->() if !defined $function;
    $dispatch_for->{showerror}->($function) unless exists $dispatch_for->{$function};
    defined $dispatch_for->{$function}->();
}

sub do_sub {
    my $module = shift;
    my $subroutine = shift;
    eval "require API::$module" or Error::report_error("500", "Runtime Error:", $@);
    my %hash = %cgi_params;
    my $coderef = "$module\:\:$subroutine(\\%hash)"  or Error::report_error("500", "Runtime Error:", $@);
    eval "{ &$coderef };"  or Error::report_error("500", "Runtime Error:", $@) ;
}

1;
