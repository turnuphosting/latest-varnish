#!/usr/bin/perl

# cPanel Varnish Cache Manager Plugin
# User-facing CGI script for cPanel interface

use strict;
use warnings;
use CGI;
use JSON;
use Template;
use Cpanel::Form ();
use lib './lib';
use VarnishUserManager;

# Initialize CGI object
my $cgi = CGI->new();

# Initialize Template Toolkit
my $template = Template->new({
    INCLUDE_PATH => './templates',
    INTERPOLATE  => 1,
    POST_CHOMP   => 1,
    EVAL_PERL    => 1,
});

# Get user information from cPanel environment
my $user = $ENV{REMOTE_USER} || $cgi->param('user') || '';
my $domain = $ENV{HTTP_HOST} || $cgi->param('domain') || '';

# Initialize Varnish user manager
my $varnish_user = VarnishUserManager->new(
    user => $user,
    domain => $domain
);

# Get action parameter
my $action = $cgi->param('action') || 'main';

# CSRF protection
my $csrf_token = $cgi->param('csrf_token') || '';
my $session_token = Cpanel::Form::generate_token();

# Content-Type header
print $cgi->header(-type => 'text/html', -charset => 'utf-8');

# Route actions
if ($action eq 'main') {
    show_main_interface();
} elsif ($action eq 'ajax') {
    handle_ajax_request();
} elsif ($action eq 'purge') {
    handle_cache_purge();
} elsif ($action eq 'stats') {
    show_statistics();
} else {
    show_error("Invalid action specified");
}

sub show_main_interface {
    my $user_domains = get_user_domains($user);
    my $cache_stats = get_user_cache_stats($user_domains);
    
    my $data = {
        page_title => 'Varnish Cache Manager',
        csrf_token => $session_token,
        user => $user,
        domain => $domain,
        user_domains => $user_domains,
        cache_stats => $cache_stats,
        recent_activity => get_recent_activity($user_domains),
        varnish_enabled => is_varnish_enabled(),
    };
    
    $template->process('main_user.tt', $data) || die $template->error();
}

sub handle_ajax_request {
    my $ajax_action = $cgi->param('ajax_action') || '';
    
    # Validate CSRF token for state-changing operations
    if ($ajax_action =~ /^(purge|clear)/ && !Cpanel::Form::validate_token($csrf_token)) {
        print_json_error("Invalid CSRF token");
        return;
    }
    
    print $cgi->header(-type => 'application/json', -charset => 'utf-8');
    
    if ($ajax_action eq 'getDomainStats') {
        my $domain = $cgi->param('domain') || '';
        print_json_response(get_domain_cache_stats($domain));
    } elsif ($ajax_action eq 'getUrlStats') {
        my $domain = $cgi->param('domain') || '';
        print_json_response(get_url_statistics($domain));
    } elsif ($ajax_action eq 'purgeUrl') {
        my $url = $cgi->param('url') || '';
        print_json_response(purge_url_cache($url));
    } elsif ($ajax_action eq 'purgeDomain') {
        my $domain = $cgi->param('domain') || '';
        print_json_response(purge_domain_cache($domain));
    } elsif ($ajax_action eq 'getRealTimeStats') {
        my $domain = $cgi->param('domain') || '';
        print_json_response(get_real_time_stats($domain));
    } elsif ($ajax_action eq 'getTopUrls') {
        my $domain = $cgi->param('domain') || '';
        print_json_response(get_top_cached_urls($domain));
    } else {
        print_json_error("Unknown AJAX action: $ajax_action");
    }
}

sub handle_cache_purge {
    if ($cgi->request_method() ne 'POST') {
        show_error("Invalid request method");
        return;
    }
    
    if (!Cpanel::Form::validate_token($csrf_token)) {
        show_error("Invalid CSRF token");
        return;
    }
    
    my $purge_type = $cgi->param('purge_type') || '';
    my $target = $cgi->param('target') || '';
    
    my $result;
    if ($purge_type eq 'url') {
        $result = purge_url_cache($target);
    } elsif ($purge_type eq 'domain') {
        $result = purge_domain_cache($target);
    } elsif ($purge_type eq 'pattern') {
        my $pattern = $cgi->param('pattern') || '';
        $result = purge_pattern_cache($target, $pattern);
    } else {
        show_error("Invalid purge type specified");
        return;
    }
    
    if ($result->{success}) {
        show_success("Cache purged successfully. Purged " . $result->{purged_count} . " items.");
    } else {
        show_error("Failed to purge cache: " . $result->{error});
    }
}

sub show_statistics {
    my $domain = $cgi->param('domain') || '';
    my $timeframe = $cgi->param('timeframe') || '24h';
    
    my $data = {
        page_title => 'Cache Statistics',
        csrf_token => $session_token,
        user => $user,
        domain => $domain,
        timeframe => $timeframe,
        stats => get_detailed_statistics($domain, $timeframe),
        charts_data => get_charts_data($domain, $timeframe),
    };
    
    $template->process('statistics.tt', $data) || die $template->error();
}

sub get_user_domains {
    my $username = shift;
    
    # Get domains for this user from cPanel
    my @domains = ();
    
    # Read from cPanel's domain configuration
    if (open my $fh, '<', "/var/cpanel/users/$username") {
        while (my $line = <$fh>) {
            chomp $line;
            if ($line =~ /^DNS=(.+)$/) {
                push @domains, $1;
            } elsif ($line =~ /^SUB=(.+)$/) {
                push @domains, $1;
            }
        }
        close $fh;
    }
    
    return \@domains;
}

sub get_user_cache_stats {
    my $domains = shift;
    my %stats = ();
    
    foreach my $domain (@$domains) {
        $stats{$domain} = $varnish_user->get_domain_stats($domain);
    }
    
    return \%stats;
}

sub get_recent_activity {
    my $domains = shift;
    my @activity = ();
    
    foreach my $domain (@$domains) {
        my $domain_activity = $varnish_user->get_recent_activity($domain, 20);
        push @activity, @$domain_activity if $domain_activity;
    }
    
    # Sort by timestamp
    @activity = sort { $b->{timestamp} <=> $a->{timestamp} } @activity;
    
    # Return only the most recent 50 items
    return [splice(@activity, 0, 50)];
}

sub is_varnish_enabled {
    return $varnish_user->is_enabled();
}

sub get_domain_cache_stats {
    my $domain = shift;
    
    # Validate domain belongs to user
    my $user_domains = get_user_domains($user);
    unless (grep { $_ eq $domain } @$user_domains) {
        return { success => 0, error => "Domain not found or access denied" };
    }
    
    my $stats = $varnish_user->get_domain_stats($domain);
    return {
        success => 1,
        data => $stats
    };
}

sub get_url_statistics {
    my $domain = shift;
    
    # Validate domain belongs to user
    my $user_domains = get_user_domains($user);
    unless (grep { $_ eq $domain } @$user_domains) {
        return { success => 0, error => "Domain not found or access denied" };
    }
    
    my $urls = $varnish_user->get_url_stats($domain);
    return {
        success => 1,
        data => $urls
    };
}

sub purge_url_cache {
    my $url = shift;
    
    # Extract domain from URL and validate
    my ($domain) = $url =~ m{^https?://([^/]+)};
    unless ($domain) {
        return { success => 0, error => "Invalid URL format" };
    }
    
    my $user_domains = get_user_domains($user);
    unless (grep { $_ eq $domain } @$user_domains) {
        return { success => 0, error => "Domain not found or access denied" };
    }
    
    return $varnish_user->purge_url($url);
}

sub purge_domain_cache {
    my $domain = shift;
    
    # Validate domain belongs to user
    my $user_domains = get_user_domains($user);
    unless (grep { $_ eq $domain } @$user_domains) {
        return { success => 0, error => "Domain not found or access denied" };
    }
    
    return $varnish_user->purge_domain($domain);
}

sub purge_pattern_cache {
    my ($domain, $pattern) = @_;
    
    # Validate domain belongs to user
    my $user_domains = get_user_domains($user);
    unless (grep { $_ eq $domain } @$user_domains) {
        return { success => 0, error => "Domain not found or access denied" };
    }
    
    return $varnish_user->purge_pattern($domain, $pattern);
}

sub get_real_time_stats {
    my $domain = shift;
    
    # Validate domain belongs to user
    my $user_domains = get_user_domains($user);
    unless (grep { $_ eq $domain } @$user_domains) {
        return { success => 0, error => "Domain not found or access denied" };
    }
    
    my $stats = $varnish_user->get_real_time_stats($domain);
    return {
        success => 1,
        data => $stats,
        timestamp => time()
    };
}

sub get_top_cached_urls {
    my $domain = shift;
    
    # Validate domain belongs to user
    my $user_domains = get_user_domains($user);
    unless (grep { $_ eq $domain } @$user_domains) {
        return { success => 0, error => "Domain not found or access denied" };
    }
    
    my $urls = $varnish_user->get_top_urls($domain, 50);
    return {
        success => 1,
        data => $urls
    };
}

sub get_detailed_statistics {
    my ($domain, $timeframe) = @_;
    
    # Validate domain belongs to user if specified
    if ($domain) {
        my $user_domains = get_user_domains($user);
        unless (grep { $_ eq $domain } @$user_domains) {
            return { error => "Domain not found or access denied" };
        }
    }
    
    return $varnish_user->get_detailed_stats($domain, $timeframe);
}

sub get_charts_data {
    my ($domain, $timeframe) = @_;
    
    # Validate domain belongs to user if specified
    if ($domain) {
        my $user_domains = get_user_domains($user);
        unless (grep { $_ eq $domain } @$user_domains) {
            return { error => "Domain not found or access denied" };
        }
    }
    
    return $varnish_user->get_charts_data($domain, $timeframe);
}

sub print_json_response {
    my $data = shift;
    print encode_json($data);
}

sub print_json_error {
    my $message = shift;
    print encode_json({ success => 0, error => $message });
}

sub show_error {
    my $message = shift;
    my $data = {
        page_title => 'Error',
        error_message => $message,
        csrf_token => $session_token,
        user => $user,
    };
    $template->process('error_user.tt', $data) || die $template->error();
}

sub show_success {
    my $message = shift;
    my $data = {
        page_title => 'Success',
        success_message => $message,
        csrf_token => $session_token,
        user => $user,
    };
    $template->process('success_user.tt', $data) || die $template->error();
}

1;