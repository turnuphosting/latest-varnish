package VarnishManager;

# VarnishManager.pm - Core Varnish management module
# Handles Varnish cache operations, configuration, and statistics

use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use File::Slurp;
use Time::HiRes qw(time);

sub new {
    my $class = shift;
    my %args = @_;
    
    my $self = {
        varnish_host => $args{host} || '127.0.0.1',
        varnish_port => $args{port} || '80',
        admin_port => $args{admin_port} || '6082',
        config_file => $args{config_file} || '/etc/varnish/default.vcl',
        service_name => $args{service_name} || 'varnish',
        ua => LWP::UserAgent->new(timeout => 10),
    };
    
    bless $self, $class;
    return $self;
}

sub get_status {
    my $self = shift;
    
    my $status = {
        running => $self->is_running(),
        version => $self->get_version(),
        uptime => $self->get_uptime(),
        config_valid => $self->validate_config(),
    };
    
    return $status;
}

sub is_running {
    my $self = shift;
    
    my $status = `systemctl is-active $self->{service_name} 2>/dev/null`;
    chomp $status;
    
    return $status eq 'active';
}

sub get_version {
    my $self = shift;
    
    my $version = `varnishd -V 2>&1 | head -1`;
    chomp $version;
    
    if ($version =~ /varnish-(\d+\.\d+\.\d+)/) {
        return $1;
    }
    
    return 'unknown';
}

sub get_uptime {
    my $self = shift;
    
    if (!$self->is_running()) {
        return 0;
    }
    
    my $uptime_str = `systemctl show $self->{service_name} --property=ActiveEnterTimestamp --value 2>/dev/null`;
    chomp $uptime_str;
    
    if ($uptime_str) {
        # Parse timestamp and calculate uptime
        my $start_time = `date -d "$uptime_str" +%s 2>/dev/null`;
        chomp $start_time;
        
        if ($start_time) {
            return time() - $start_time;
        }
    }
    
    return 0;
}

sub validate_config {
    my $self = shift;
    
    my $output = `varnishd -C -f $self->{config_file} 2>&1`;
    my $exit_code = $? >> 8;
    
    return $exit_code == 0;
}

sub get_stats {
    my $self = shift;
    
    my $stats = {};
    
    # Get Varnish statistics using varnishstat
    my $varnishstat_output = `varnishstat -1 -j 2>/dev/null`;
    
    if ($varnishstat_output) {
        eval {
            my $data = decode_json($varnishstat_output);
            
            # Extract key metrics
            $stats = {
                cache_hits => $data->{MAIN}->{cache_hit}->{value} || 0,
                cache_misses => $data->{MAIN}->{cache_miss}->{value} || 0,
                cache_hit_rate => $self->calculate_hit_rate($data),
                backend_connections => $data->{MAIN}->{backend_conn}->{value} || 0,
                client_connections => $data->{MAIN}->{client_conn}->{value} || 0,
                objects_in_cache => $data->{MAIN}->{n_object}->{value} || 0,
                bytes_allocated => $data->{MAIN}->{s0_g_bytes}->{value} || 0,
                bytes_free => $data->{MAIN}->{s0_g_space}->{value} || 0,
                requests_per_second => $self->calculate_requests_per_second($data),
                average_response_time => $self->get_average_response_time(),
                backend_fetch_errors => $data->{MAIN}->{backend_fail}->{value} || 0,
                sessions_dropped => $data->{MAIN}->{sess_drop}->{value} || 0,
                threads_created => $data->{MAIN}->{threads_created}->{value} || 0,
                threads_destroyed => $data->{MAIN}->{threads_destroyed}->{value} || 0,
            };
            
            # Calculate derived metrics
            $stats->{total_requests} = $stats->{cache_hits} + $stats->{cache_misses};
            $stats->{memory_usage_percentage} = $self->calculate_memory_usage($stats);
            
        };
        if ($@) {
            warn "Error parsing varnishstat output: $@";
        }
    }
    
    return $stats;
}

sub calculate_hit_rate {
    my ($self, $data) = @_;
    
    my $hits = $data->{MAIN}->{cache_hit}->{value} || 0;
    my $misses = $data->{MAIN}->{cache_miss}->{value} || 0;
    my $total = $hits + $misses;
    
    return $total > 0 ? ($hits / $total) * 100 : 0;
}

sub calculate_requests_per_second {
    my ($self, $data) = @_;
    
    my $uptime = $self->get_uptime();
    return 0 unless $uptime > 0;
    
    my $total_requests = ($data->{MAIN}->{cache_hit}->{value} || 0) + 
                        ($data->{MAIN}->{cache_miss}->{value} || 0);
    
    return $total_requests / $uptime;
}

sub get_average_response_time {
    my $self = shift;
    
    # This would typically require more detailed logging analysis
    # For now, return a placeholder value
    return 0.1; # 100ms placeholder
}

sub calculate_memory_usage {
    my ($self, $stats) = @_;
    
    my $allocated = $stats->{bytes_allocated} || 0;
    my $free = $stats->{bytes_free} || 0;
    my $total = $allocated + $free;
    
    return $total > 0 ? ($allocated / $total) * 100 : 0;
}

sub get_analytics {
    my ($self, $timeframe) = @_;
    
    # Convert timeframe to hours
    my $hours = 1;
    if ($timeframe =~ /^(\d+)h$/) {
        $hours = $1;
    } elsif ($timeframe =~ /^(\d+)d$/) {
        $hours = $1 * 24;
    }
    
    # Generate sample analytics data points
    my @analytics = ();
    my $current_time = time();
    my $interval = ($hours * 3600) / 50; # 50 data points
    
    for my $i (0..49) {
        my $timestamp = $current_time - (49 - $i) * $interval;
        
        push @analytics, {
            timestamp => $timestamp,
            hit_rate => 85 + rand(10), # 85-95%
            response_time => 50 + rand(100), # 50-150ms
            bandwidth_usage => (1000000 + rand(5000000)) * (0.8 + rand(0.4)), # Variable bandwidth
            request_count => 100 + rand(200), # 100-300 requests
        };
    }
    
    return \@analytics;
}

sub get_domain_statistics {
    my $self = shift;
    
    # Parse Varnish logs to get domain-specific statistics
    my %domains = ();
    
    # Use varnishlog to get recent requests
    my $log_output = `varnishlog -n /var/lib/varnish -d -g request | head -1000 2>/dev/null`;
    
    my @lines = split /\n/, $log_output;
    my $current_domain = '';
    
    foreach my $line (@lines) {
        if ($line =~ /Host:\s+(.+)/) {
            $current_domain = $1;
            $current_domain =~ s/\r//g; # Remove carriage return
            
            $domains{$current_domain} ||= {
                requests => 0,
                hits => 0,
                misses => 0,
                bytes_sent => 0,
                avg_response_time => 0,
                hit_rate => 0,
            };
            
            $domains{$current_domain}->{requests}++;
        } elsif ($line =~ /Hit/ && $current_domain) {
            $domains{$current_domain}->{hits}++;
        } elsif ($line =~ /Miss/ && $current_domain) {
            $domains{$current_domain}->{misses}++;
        }
    }
    
    # Calculate hit rates
    foreach my $domain (keys %domains) {
        my $total = $domains{$domain}->{hits} + $domains{$domain}->{misses};
        if ($total > 0) {
            $domains{$domain}->{hit_rate} = ($domains{$domain}->{hits} / $total) * 100;
        }
    }
    
    return \%domains;
}

sub purge_cache {
    my ($self, $domain, $path) = @_;
    
    my $purge_url = "http://$domain";
    $purge_url .= $path if $path;
    
    # Use varnishadm to purge cache
    my $command = qq{varnishadm ban "req.http.host == '$domain'"};
    if ($path) {
        $command = qq{varnishadm ban "req.http.host == '$domain' && req.url ~ '^$path'"};
    }
    
    my $output = `$command 2>&1`;
    my $exit_code = $? >> 8;
    
    if ($exit_code == 0) {
        return {
            success => 1,
            message => "Cache purged successfully",
            purged_count => $self->count_purged_objects($output),
        };
    } else {
        return {
            success => 0,
            message => "Failed to purge cache: $output",
        };
    }
}

sub purge_all {
    my $self = shift;
    
    my $command = "varnishadm ban req.url '~' '.'";
    my $output = `$command 2>&1`;
    my $exit_code = $? >> 8;
    
    if ($exit_code == 0) {
        return {
            success => 1,
            message => "All cache purged successfully",
            purged_count => $self->count_purged_objects($output),
        };
    } else {
        return {
            success => 0,
            message => "Failed to purge all cache: $output",
        };
    }
}

sub count_purged_objects {
    my ($self, $output) = @_;
    
    # Parse varnishadm output to count purged objects
    # This is a simplified implementation
    if ($output =~ /(\d+)/) {
        return $1;
    }
    
    return 0;
}

sub restart_service {
    my $self = shift;
    
    my $output = `systemctl restart $self->{service_name} 2>&1`;
    my $exit_code = $? >> 8;
    
    if ($exit_code == 0) {
        return {
            success => 1,
            message => "Varnish service restarted successfully",
        };
    } else {
        return {
            success => 0,
            message => "Failed to restart Varnish service: $output",
        };
    }
}

sub get_config {
    my $self = shift;
    
    my $config = {};
    
    # Read Varnish configuration file
    if (-f $self->{config_file}) {
        $config->{vcl_content} = read_file($self->{config_file});
    }
    
    # Read systemd service configuration
    my $service_file = "/etc/systemd/system/$self->{service_name}.service";
    if (-f $service_file) {
        my $service_content = read_file($service_file);
        
        # Extract port and memory settings
        if ($service_content =~ /-a :(\d+)/) {
            $config->{port} = $1;
        }
        if ($service_content =~ /-s malloc,(\d+\w+)/) {
            $config->{memory} = $1;
        }
    }
    
    return $config;
}

sub save_config {
    my ($self, $config) = @_;
    
    eval {
        # Save VCL configuration
        if ($config->{vcl_content}) {
            write_file($self->{config_file}, $config->{vcl_content});
        }
        
        # Update systemd service configuration
        if ($config->{port} || $config->{memory}) {
            $self->update_service_config($config);
        }
        
        # Validate configuration
        unless ($self->validate_config()) {
            die "Invalid VCL configuration";
        }
        
        return { success => 1, message => "Configuration saved successfully" };
    };
    if ($@) {
        return { success => 0, error => "Failed to save configuration: $@" };
    }
}

sub update_service_config {
    my ($self, $config) = @_;
    
    my $service_file = "/etc/systemd/system/$self->{service_name}.service";
    
    if (-f $service_file) {
        my $content = read_file($service_file);
        
        if ($config->{port}) {
            $content =~ s/-a :\d+/-a :$config->{port}/g;
        }
        
        if ($config->{memory}) {
            $content =~ s/-s malloc,\d+\w+/-s malloc,$config->{memory}/g;
        }
        
        write_file($service_file, $content);
        
        # Reload systemd configuration
        system("systemctl daemon-reload");
    }
}

sub configure {
    my ($self, $config) = @_;
    
    # Update Varnish configuration based on installation requirements
    my $vcl_config = $self->generate_vcl_config($config);
    
    eval {
        # Write VCL configuration
        write_file($self->{config_file}, $vcl_config);
        
        # Update service configuration
        $self->update_service_ports($config);
        
        # Validate configuration
        unless ($self->validate_config()) {
            die "Generated VCL configuration is invalid";
        }
        
        return { success => 1, message => "Varnish configured successfully" };
    };
    if ($@) {
        return { success => 0, error => "Failed to configure Varnish: $@" };
    }
}

sub generate_vcl_config {
    my ($self, $config) = @_;
    
    my $apache_port = $config->{apache_port} || '8080';
    my $server_ip = $config->{server_ip} || '127.0.0.1';
    
    my $vcl = qq{vcl 4.1;

import proxy;

backend default {
    .host = "$server_ip";
    .port = "$apache_port";
}

sub vcl_recv {
    if(!req.http.X-Forwarded-Proto) {
        if (proxy.is_ssl()) {
            set req.http.X-Forwarded-Proto = "https";
        } else {
            set req.http.X-Forwarded-Proto = "http";
        }
    }
    
    # Remove any existing Varnish cache headers from client
    unset req.http.X-Varnish;
    unset req.http.Via;
    unset req.http.X-Forwarded-For;
    
    # Set X-Forwarded-For header
    if (req.http.X-Forwarded-For) {
        set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
    } else {
        set req.http.X-Forwarded-For = client.ip;
    }
    
    # Handle purge requests
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return(synth(405, "Method not allowed"));
        }
        return(purge);
    }
    
    # Only cache GET and HEAD requests
    if (req.method != "GET" && req.method != "HEAD") {
        return(pass);
    }
    
    # Don't cache requests with authentication
    if (req.http.Authorization) {
        return(pass);
    }
    
    # Don't cache WordPress admin, login, or dynamic pages
    if (req.url ~ "wp-(admin|login|cron)" ||
        req.url ~ "\\?.*" ||
        req.url ~ "preview=true" ||
        req.url ~ "xmlrpc.php") {
        return(pass);
    }
    
    # Remove WordPress cookies for static content
    if (req.url ~ "\\.(css|js|png|gif|jp(e)?g|swf|ico|woff|woff2|ttf|eot|svg)\$") {
        unset req.http.cookie;
    }
    
    return(hash);
}

sub vcl_backend_response {
    if(beresp.http.Vary) {
        set beresp.http.Vary = beresp.http.Vary + ", X-Forwarded-Proto";
    } else {
        set beresp.http.Vary = "X-Forwarded-Proto";
    }
    
    # Cache static files for 1 week
    if (bereq.url ~ "\\.(css|js|png|gif|jp(e)?g|swf|ico|woff|woff2|ttf|eot|svg)\$") {
        set beresp.ttl = 7d;
        set beresp.http.Cache-Control = "public, max-age=604800";
    }
    
    # Don't cache if there are cookies or cache-control headers
    if (beresp.http.Set-Cookie || beresp.http.Cache-Control ~ "private|no-cache|no-store") {
        set beresp.ttl = 0s;
        set beresp.uncacheable = true;
        return(deliver);
    }
    
    # Default cache time for other content
    set beresp.ttl = 1h;
    
    return(deliver);
}

sub vcl_deliver {
    # Add cache status header
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
        set resp.http.X-Cache-Hits = obj.hits;
    } else {
        set resp.http.X-Cache = "MISS";
    }
    
    # Remove backend server information
    unset resp.http.Server;
    unset resp.http.X-Powered-By;
    unset resp.http.X-Varnish;
    unset resp.http.Via;
    unset resp.http.Age;
    
    return(deliver);
}

# Access control list for purge requests
acl purge {
    "localhost";
    "127.0.0.1";
    "$server_ip";
}
};

    return $vcl;
}

sub update_service_ports {
    my ($self, $config) = @_;
    
    my $varnish_port = $config->{varnish_port} || '80';
    my $hitch_backend_port = $config->{hitch_backend_port} || '4443';
    
    my $service_file = "/etc/systemd/system/$self->{service_name}.service";
    
    if (-f $service_file) {
        my $content = read_file($service_file);
        
        # Update ExecStart line with new ports
        $content =~ s{ExecStart=/usr/sbin/varnishd.*}{ExecStart=/usr/sbin/varnishd -a :$varnish_port -a 127.0.0.1:$hitch_backend_port,proxy -f $self->{config_file} -s malloc,256m}g;
        
        write_file($service_file, $content);
        
        # Reload systemd configuration
        system("systemctl daemon-reload");
    }
}

sub get_recent_logs {
    my ($self, $limit) = @_;
    $limit ||= 100;
    
    my @logs = ();
    
    # Get recent Varnish logs
    my $log_output = `journalctl -u $self->{service_name} --lines=$limit --output=json --no-pager 2>/dev/null`;
    
    my @lines = split /\n/, $log_output;
    foreach my $line (@lines) {
        next unless $line;
        
        eval {
            my $entry = decode_json($line);
            push @logs, {
                timestamp => $entry->{__REALTIME_TIMESTAMP} / 1000000,
                level => $entry->{PRIORITY} || 'info',
                message => $entry->{MESSAGE} || '',
                source => 'varnish',
            };
        };
    }
    
    return \@logs;
}

1;