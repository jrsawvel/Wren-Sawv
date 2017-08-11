package Client::cDispatch;

use strict;
use warnings;
use diagnostics;

use Client::cModules;
use Shared::RequestURI;

my %cgi_params = RequestURI::get_cgi_params_from_path_info();

my $dispatch_for = {
    showerror          =>   sub { return \&do_sub(       "Function",       "do_invalid_function"      ) },
    createpost         =>   sub { return \&do_sub(       "CreatePost",     "create_post"              ) },
    create             =>   sub { return \&do_sub(       "CreatePost",     "show_new_post_form"       ) },
    update             =>   sub { return \&do_sub(       "UpdatePost",     "show_post_to_edit"        ) },
    updatepost         =>   sub { return \&do_sub(       "UpdatePost",     "update_post"              ) },
    login              =>   sub { return \&do_sub(       "User",           "show_login_form"          ) },
    logout             =>   sub { return \&do_sub(       "User",           "logout"                   ) },
    dologin            =>   sub { return \&do_sub(       "User",           "do_login"                 ) },
    nopwdlogin         =>   sub { return \&do_sub(       "User",           "no_password_login"        ) },
    editorcreate       =>   sub { return \&do_sub(       "CreatePost",     "show_editor_create"       ) },
    editorupdate       =>   sub { return \&do_sub(       "UpdatePost",     "show_editor_update"       ) },
    search             =>   sub { return \&do_sub(       "Search",         "search"                   ) },
    webmention         =>   sub { return \&do_sub(       "Webmention",     "webmention"               ) },
    indieauth          =>   sub { return \&do_sub(       "User",           "indie_auth_login"         ) },
};

sub execute {
    my $function = $cgi_params{0};

if ( !defined($function) or !$function )  {
    Page->report_error("user", "Client Invalid function: ", "It's not supported.");
}



    $dispatch_for->{showerror}->() if !defined($function) or !$function;

    $dispatch_for->{showerror}->($function) unless exists $dispatch_for->{$function} ;

    defined $dispatch_for->{$function}->();
}

sub do_sub {
    my $module = shift;
    my $subroutine = shift;
    eval "require Client::$module" or Page->report_error("user", "Runtime Error (1):", $@);
    my %hash = %cgi_params;
    my $coderef = "$module\:\:$subroutine(\\%hash)"  or Page->report_error("user", "Runtime Error (2):", $@);
    eval "{ &$coderef };" or Page->report_error("user", "Runtime Error (2):", $@) ;
}

1;
