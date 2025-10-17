#!/usr/bin/perl

# WHM Varnish Cache Manager Plugin
# Main CGI script for the WHM interface

use strict;
use warnings;
use CGI;
use JSON;
use Template;
use lib './lib';
use VarnishManager;
use HitchManager;

# Initialize CGI object
my $cgi = CGI->new();

# Initialize Template Toolkit
my $template = Template->new({
    INCLUDE_PATH => './templates',
    INTERPOLATE  => 1,
    POST_CHOMP   => 1,
    EVAL_PERL    => 1,
});

# Initialize managers
my $varnish = VarnishManager->new();
my $hitch = HitchManager->new();

# Get action parameter
my $action = $cgi->param('action') || 'main';

# CSRF protection
my $csrf_token = $cgi->param('csrf_token') || '';
my $session_token = generate_csrf_token();

# Content-Type header
print $cgi->header(-type => 'text/html', -charset => 'utf-8');

# Route actions
if ($action eq 'main') {
    show_main_interface();
} elsif ($action eq 'ajax') {
    handle_ajax_request();
} elsif ($action eq 'install') {
    handle_installation();
} elsif ($action eq 'configure') {
    handle_configuration();
} else {
    show_error("Invalid action specified");
}

sub show_main_interface {
    my $data = {
        page_title => 'Varnish Cache Manager',
        csrf_token => $session_token,
        varnish_status => $varnish->get_status(),
        hitch_status => $hitch->get_status(),
        system_stats => get_system_stats(),
        domain_stats => get_domain_stats(),
        recent_logs => get_recent_logs(),
    };
    
    $template->process('main.tt', $data) || die $template->error();
}

sub handle_ajax_request {
    my $ajax_action = $cgi->param('ajax_action') || '';
    
    # Validate CSRF token for state-changing operations
    if ($ajax_action =~ /^(purge|configure|install|restart)/ && !validate_csrf_token($csrf_token)) {
        print_json_error("Invalid CSRF token");
        return;
    }
    
    print $cgi->header(-type => 'application/json', -charset => 'utf-8');
    
    if ($ajax_action eq 'getStats') {
        print_json_response(get_real_time_stats());
    } elsif ($ajax_action eq 'getAnalytics') {
        my $timeframe = $cgi->param('timeframe') || '1h';
        print_json_response(get_analytics($timeframe));
    } elsif ($ajax_action eq 'getDomainStats') {
        print_json_response(get_domain_stats());
    } elsif ($ajax_action eq 'purgeCache') {
        my $domain = $cgi->param('domain') || '';
        my $path = $cgi->param('path') || '';
        print_json_response(purge_cache($domain, $path));
    } elsif ($ajax_action eq 'purgeAll') {
        print_json_response(purge_all_cache());
    } elsif ($ajax_action eq 'restartVarnish') {
        print_json_response(restart_varnish());
    } elsif ($ajax_action eq 'restartHitch') {
        print_json_response(restart_hitch());
    } elsif ($ajax_action eq 'getConfig') {
        print_json_response(get_configuration());
    } elsif ($ajax_action eq 'saveConfig') {
        my $config = decode_json($cgi->param('config') || '{}');
        print_json_response(save_configuration($config));
    } else {
        print_json_error("Unknown AJAX action: $ajax_action");
    }
}

sub handle_installation {
    print $cgi->header(-type => 'application/json', -charset => 'utf-8');
    
    if (!validate_csrf_token($csrf_token)) {
        print_json_error("Invalid CSRF token");
        return;
    }
    
    my $install_type = $cgi->param('install_type') || 'full';
    my $result = perform_installation($install_type);
    print_json_response($result);
}

sub handle_configuration {
    if ($cgi->request_method() eq 'POST') {
        if (!validate_csrf_token($csrf_token)) {
            show_error("Invalid CSRF token");
            return;
        }
        
        my $config = {
            apache_port => $cgi->param('apache_port') || '8080',
            apache_ssl_port => $cgi->param('apache_ssl_port') || '8443',
            varnish_port => $cgi->param('varnish_port') || '80',
            varnish_memory => $cgi->param('varnish_memory') || '256m',
            hitch_port => $cgi->param('hitch_port') || '443',
            hitch_backend => $cgi->param('hitch_backend') || '127.0.0.1:4443',
        };
        
        my $result = apply_configuration($config);
        if ($result->{success}) {
            show_success("Configuration applied successfully");
        } else {
            show_error("Failed to apply configuration: " . $result->{error});
        }
    } else {
        show_configuration_form();
    }
}

sub get_real_time_stats {
    return {
        success => 1,
        data => {
            varnish => $varnish->get_stats(),
            hitch => $hitch->get_stats(),
            system => get_system_metrics(),
            timestamp => time(),
        }
    };
}

sub get_analytics {
    my $timeframe = shift;
    my $analytics = $varnish->get_analytics($timeframe);
    return {
        success => 1,
        data => $analytics
    };
}

sub get_domain_stats {
    my $domains = $varnish->get_domain_statistics();
    return {
        success => 1,
        data => $domains
    };
}

sub purge_cache {
    my ($domain, $path) = @_;
    my $result = $varnish->purge_cache($domain, $path);
    return {
        success => $result->{success},
        message => $result->{message},
        purged_count => $result->{purged_count} || 0
    };
}

sub purge_all_cache {
    my $result = $varnish->purge_all();
    return {
        success => $result->{success},
        message => $result->{message},
        purged_count => $result->{purged_count} || 0
    };
}

sub restart_varnish {
    my $result = $varnish->restart_service();
    return {
        success => $result->{success},
        message => $result->{message}
    };
}

sub restart_hitch {
    my $result = $hitch->restart_service();
    return {
        success => $result->{success},
        message => $result->{message}
    };
}

sub get_configuration {
    return {
        success => 1,
        data => {
            varnish => $varnish->get_config(),
            hitch => $hitch->get_config(),
            apache => get_apache_config()
        }
    };
}

sub save_configuration {
    my $config = shift;
    
    my $varnish_result = $varnish->save_config($config->{varnish});
    my $hitch_result = $hitch->save_config($config->{hitch});
    my $apache_result = save_apache_config($config->{apache});
    
    if ($varnish_result->{success} && $hitch_result->{success} && $apache_result->{success}) {
        return {
            success => 1,
            message => "Configuration saved successfully"
        };
    } else {
        return {
            success => 0,
            message => "Failed to save configuration",
            errors => [
                ($varnish_result->{error} || ()),
                ($hitch_result->{error} || ()),
                ($apache_result->{error} || ())
            ]
        };
    }
}

sub perform_installation {
    my $install_type = shift;
    
    # Create installation manager
    require InstallationManager;
    my $installer = InstallationManager->new();
    
    return $installer->install($install_type);
}

sub apply_configuration {
    my $config = shift;
    
    # Apply Apache configuration changes
    my $apache_result = configure_apache($config);
    return $apache_result unless $apache_result->{success};
    
    # Apply Varnish configuration
    my $varnish_result = $varnish->configure($config);
    return $varnish_result unless $varnish_result->{success};
    
    # Apply Hitch configuration
    my $hitch_result = $hitch->configure($config);
    return $hitch_result unless $hitch_result->{success};
    
    return { success => 1, message => "All configurations applied successfully" };
}

sub configure_apache {
    my $config = shift;
    
    # Backup current configuration
    system("cp -a /var/cpanel/cpanel.config /var/cpanel/cpanel.config-backup");
    
    # Update cPanel configuration
    my $cpanel_config = read_file('/var/cpanel/cpanel.config');
    $cpanel_config =~ s/apache_port=.*$/apache_port=0.0.0.0:$config->{apache_port}/gm;
    $cpanel_config =~ s/apache_ssl_port=.*$/apache_ssl_port=0.0.0.0:$config->{apache_ssl_port}/gm;
    
    write_file('/var/cpanel/cpanel.config', $cpanel_config);
    
    # Rebuild Apache configuration
    system("/scripts/rebuildhttpdconf");
    system("/scripts/restartsrv_httpd");
    
    return { success => 1, message => "Apache configuration updated" };
}

sub get_system_stats {
    return {
        load_average => `uptime | awk '{print \$(NF-2)}' | sed 's/,//'`,
        memory_usage => get_memory_usage(),
        disk_usage => get_disk_usage(),
        network_stats => get_network_stats(),
    };
}

sub get_system_metrics {
    return {
        cpu_usage => get_cpu_usage(),
        memory_usage => get_memory_usage(),
        network_io => get_network_io(),
        disk_io => get_disk_io(),
    };
}

sub get_recent_logs {
    my @logs = ();
    
    # Get Varnish logs
    my $varnish_logs = $varnish->get_recent_logs(50);
    push @logs, @$varnish_logs if $varnish_logs;
    
    # Get Hitch logs
    my $hitch_logs = $hitch->get_recent_logs(50);
    push @logs, @$hitch_logs if $hitch_logs;
    
    # Sort by timestamp
    @logs = sort { $b->{timestamp} <=> $a->{timestamp} } @logs;
    
    return \@logs;
}

sub get_apache_config {
    # Return current Apache configuration
    return {
        port => get_apache_port(),
        ssl_port => get_apache_ssl_port(),
        status => get_apache_status()
    };
}

sub save_apache_config {
    my $config = shift;
    # Implement Apache configuration saving
    return { success => 1 };
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
    };
    $template->process('error.tt', $data) || die $template->error();
}

sub show_success {
    my $message = shift;
    my $data = {
        page_title => 'Success',
        success_message => $message,
        csrf_token => $session_token,
    };
    $template->process('success.tt', $data) || die $template->error();
}

sub show_configuration_form {
    my $data = {
        page_title => 'Configuration',
        csrf_token => $session_token,
        current_config => get_configuration()->{data},
    };
    $template->process('configuration.tt', $data) || die $template->error();
}

sub generate_csrf_token {
    # Generate a simple CSRF token
    my $token = join('', map { sprintf("%02x", rand(256)) } 1..16);
    return $token;
}

sub validate_csrf_token {
    my $token = shift;
    # Basic token validation - in production, implement proper session-based validation
    return length($token) == 32 && $token =~ /^[a-f0-9]+$/;
}

sub read_file {
    my $filename = shift;
    open my $fh, '<', $filename or die "Cannot read $filename: $!";
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub write_file {
    my ($filename, $content) = @_;
    open my $fh, '>', $filename or die "Cannot write $filename: $!";
    print $fh $content;
    close $fh;
}

# Helper functions for system metrics
sub get_memory_usage {
    my $output = `free -m | grep '^Mem:'`;
    if ($output =~ /^\s*Mem:\s+(\d+)\s+(\d+)/) {
        return {
            total => $1,
            used => $2,
            percentage => int(($2 / $1) * 100)
        };
    }
    return { total => 0, used => 0, percentage => 0 };
}

sub get_disk_usage {
    my $output = `df -h / | tail -1`;
    if ($output =~ /\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)%/) {
        return {
            total => $1,
            used => $2,
            free => $3,
            percentage => $4
        };
    }
    return { total => '0G', used => '0G', free => '0G', percentage => 0 };
}

sub get_network_stats {
    # Implement network statistics gathering
    return {
        bytes_in => 0,
        bytes_out => 0,
        packets_in => 0,
        packets_out => 0
    };
}

sub get_cpu_usage {
    my $output = `top -bn1 | grep "Cpu(s)" | awk '{print \$2}' | sed 's/%us,//'`;
    chomp $output;
    return $output || 0;
}

sub get_network_io {
    # Implement network I/O monitoring
    return { in => 0, out => 0 };
}

sub get_disk_io {
    # Implement disk I/O monitoring
    return { read => 0, write => 0 };
}

sub get_apache_port {
    my $config = read_file('/var/cpanel/cpanel.config');
    if ($config =~ /apache_port=.*?:(\d+)/) {
        return $1;
    }
    return '8080';
}

sub get_apache_ssl_port {
    my $config = read_file('/var/cpanel/cpanel.config');
    if ($config =~ /apache_ssl_port=.*?:(\d+)/) {
        return $1;
    }
    return '8443';
}

sub get_apache_status {
    my $status = `systemctl is-active httpd 2>/dev/null`;
    chomp $status;
    return $status eq 'active' ? 'running' : 'stopped';
}

1;