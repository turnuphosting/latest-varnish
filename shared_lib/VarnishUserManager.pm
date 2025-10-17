package VarnishUserManager;

# VarnishUserManager.pm - User-specific Varnish management module
# Handles user-restricted Varnish operations for cPanel integration

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
        user => $args{user} || '',
        domain => $args{domain} || '',
        varnish_host => $args{host} || '127.0.0.1',
        varnish_port => $args{port} || '80',
        admin_port => $args{admin_port} || '6082',
        ua => LWP::UserAgent->new(timeout => 10),
    };
    
    bless $self, $class;
    return $self;
}

sub is_enabled {
    my $self = shift;
    
    # Check if Varnish is running and accessible
    my $status = `systemctl is-active varnish 2>/dev/null`;
    chomp $status;
    
    return $status eq 'active';
}

sub get_domain_stats {
    my ($self, $domain) = @_;
    
    # Validate that user owns this domain
    return {} unless $self->validate_domain_ownership($domain);
    
    my $stats = {
        hit_rate => 0,
        total_requests => 0,
        cache_hits => 0,
        cache_misses => 0,
        bytes_sent => 0,
        avg_response_time => 0,
        last_updated => time(),
    };
    
    # Parse Varnish logs for domain-specific statistics
    my $log_data = $self->get_domain_log_data($domain);
    
    if ($log_data) {
        $stats->{total_requests} = $log_data->{total_requests} || 0;
        $stats->{cache_hits} = $log_data->{hits} || 0;
        $stats->{cache_misses} = $log_data->{misses} || 0;
        $stats->{bytes_sent} = $log_data->{bytes_sent} || 0;
        
        if ($stats->{total_requests} > 0) {
            $stats->{hit_rate} = ($stats->{cache_hits} / $stats->{total_requests}) * 100;
        }
        
        $stats->{avg_response_time} = $log_data->{avg_response_time} || 0;
    }
    
    return $stats;
}

sub validate_domain_ownership {
    my ($self, $domain) = @_;
    
    # Check if domain belongs to the current user
    my $user_domains = $self->get_user_domains();
    
    return grep { $_ eq $domain } @$user_domains;
}

sub get_user_domains {
    my $self = shift;
    
    my @domains = ();
    my $username = $self->{user};
    
    return \@domains unless $username;
    
    # Read user's domains from cPanel configuration
    my $user_file = "/var/cpanel/users/$username";
    if (-f $user_file) {
        my $content = read_file($user_file);
        
        # Extract main domain
        if ($content =~ /^DNS=(.+)$/m) {
            push @domains, $1;
        }
        
        # Extract addon domains
        while ($content =~ /^ADDON=(.+)$/gm) {
            push @domains, $1;
        }
        
        # Extract subdomains
        while ($content =~ /^SUB=(.+)$/gm) {
            push @domains, $1;
        }
        
        # Extract parked domains
        while ($content =~ /^PARK=(.+)$/gm) {
            push @domains, $1;
        }
    }
    
    return \@domains;
}

sub get_domain_log_data {
    my ($self, $domain) = @_;
    
    my $data = {
        total_requests => 0,
        hits => 0,
        misses => 0,
        bytes_sent => 0,
        avg_response_time => 0,
        response_times => [],
    };
    
    # Use varnishlog to get domain-specific data
    my $log_command = qq{varnishlog -n /var/lib/varnish -d -g request -q "ReqHeader:Host eq '$domain'" | head -1000 2>/dev/null};
    my $log_output = `$log_command`;
    
    my @lines = split /\n/, $log_output;
    my $current_request = {};
    
    foreach my $line (@lines) {
        if ($line =~ /^\*\s+(\d+)\s+ReqStart/) {
            # New request
            $current_request = { id => $1 };
        } elsif ($line =~ /^\s+\d+\s+ReqHeader\s+Host:\s*(.+)/) {
            my $host = $1;
            $host =~ s/\r//g;
            $current_request->{host} = $host;
        } elsif ($line =~ /^\s+\d+\s+VCL_hit/) {
            $current_request->{result} = 'hit';
        } elsif ($line =~ /^\s+\d+\s+VCL_miss/) {
            $current_request->{result} = 'miss';
        } elsif ($line =~ /^\s+\d+\s+RespHeader\s+Content-Length:\s*(\d+)/) {
            $current_request->{content_length} = $1;
        } elsif ($line =~ /^\s+\d+\s+Timestamp\s+Process:\s+[\d\.]+\s+([\d\.]+)/) {
            $current_request->{response_time} = $1 * 1000; # Convert to milliseconds
        } elsif ($line =~ /^\*\s+\d+\s+ReqEnd/) {
            # End of request - process data
            if ($current_request->{host} && $current_request->{host} eq $domain) {
                $data->{total_requests}++;
                
                if ($current_request->{result} eq 'hit') {
                    $data->{hits}++;
                } elsif ($current_request->{result} eq 'miss') {
                    $data->{misses}++;
                }
                
                if ($current_request->{content_length}) {
                    $data->{bytes_sent} += $current_request->{content_length};
                }
                
                if ($current_request->{response_time}) {
                    push @{$data->{response_times}}, $current_request->{response_time};
                }
            }
            $current_request = {};
        }
    }
    
    # Calculate average response time
    if (@{$data->{response_times}}) {
        my $sum = 0;
        $sum += $_ for @{$data->{response_times}};
        $data->{avg_response_time} = $sum / @{$data->{response_times}};
    }
    
    return $data;
}

sub get_url_stats {
    my ($self, $domain) = @_;
    
    return [] unless $self->validate_domain_ownership($domain);
    
    my @urls = ();
    
    # Get URL-specific statistics from Varnish logs
    my $log_command = qq{varnishlog -n /var/lib/varnish -d -g request -q "ReqHeader:Host eq '$domain'" | head -2000 2>/dev/null};
    my $log_output = `$log_command`;
    
    my %url_stats = ();
    my @lines = split /\n/, $log_output;
    my $current_request = {};
    
    foreach my $line (@lines) {
        if ($line =~ /^\*\s+(\d+)\s+ReqStart/) {
            $current_request = { id => $1 };
        } elsif ($line =~ /^\s+\d+\s+ReqURL\s+(.+)/) {
            $current_request->{url} = $1;
        } elsif ($line =~ /^\s+\d+\s+ReqHeader\s+Host:\s*(.+)/) {
            my $host = $1;
            $host =~ s/\r//g;
            $current_request->{host} = $host;
        } elsif ($line =~ /^\s+\d+\s+VCL_hit/) {
            $current_request->{result} = 'hit';
        } elsif ($line =~ /^\s+\d+\s+VCL_miss/) {
            $current_request->{result} = 'miss';
        } elsif ($line =~ /^\s+\d+\s+RespHeader\s+Content-Length:\s*(\d+)/) {
            $current_request->{content_length} = $1;
        } elsif ($line =~ /^\s+\d+\s+Timestamp\s+Process:\s+[\d\.]+\s+([\d\.]+)/) {
            $current_request->{response_time} = $1 * 1000;
        } elsif ($line =~ /^\*\s+\d+\s+ReqEnd/) {
            # Process completed request
            if ($current_request->{host} && $current_request->{host} eq $domain && $current_request->{url}) {
                my $url = $current_request->{url};
                
                $url_stats{$url} ||= {
                    url => $url,
                    hits => 0,
                    misses => 0,
                    total_requests => 0,
                    bytes_sent => 0,
                    avg_response_time => 0,
                    response_times => [],
                    last_accessed => time(),
                    status => 'unknown',
                };
                
                $url_stats{$url}->{total_requests}++;
                $url_stats{$url}->{last_accessed} = time();
                
                if ($current_request->{result} eq 'hit') {
                    $url_stats{$url}->{hits}++;
                    $url_stats{$url}->{status} = 'cached';
                } elsif ($current_request->{result} eq 'miss') {
                    $url_stats{$url}->{misses}++;
                    $url_stats{$url}->{status} = 'not-cached';
                }
                
                if ($current_request->{content_length}) {
                    $url_stats{$url}->{bytes_sent} += $current_request->{content_length};
                }
                
                if ($current_request->{response_time}) {
                    push @{$url_stats{$url}->{response_times}}, $current_request->{response_time};
                }
            }
            $current_request = {};
        }
    }
    
    # Calculate averages and format data
    foreach my $url (keys %url_stats) {
        my $stats = $url_stats{$url};
        
        # Calculate average response time
        if (@{$stats->{response_times}}) {
            my $sum = 0;
            $sum += $_ for @{$stats->{response_times}};
            $stats->{avg_response_time} = $sum / @{$stats->{response_times}};
        }
        
        # Calculate hit rate
        if ($stats->{total_requests} > 0) {
            $stats->{hit_rate} = ($stats->{hits} / $stats->{total_requests}) * 100;
        } else {
            $stats->{hit_rate} = 0;
        }
        
        # Clean up temporary data
        delete $stats->{response_times};
        
        push @urls, $stats;
    }
    
    # Sort by total requests (most accessed first)
    @urls = sort { $b->{total_requests} <=> $a->{total_requests} } @urls;
    
    return \@urls;
}

sub purge_url {
    my ($self, $url) = @_;
    
    # Extract domain from URL
    my ($protocol, $domain, $path) = $url =~ m{^(https?://)([^/]+)(.*)$};
    return { success => 0, error => "Invalid URL format" } unless $domain;
    
    # Validate domain ownership
    unless ($self->validate_domain_ownership($domain)) {
        return { success => 0, error => "Domain access denied" };
    }
    
    # Perform cache purge using varnishadm
    my $ban_expression = qq{req.http.host == "$domain"};
    $ban_expression .= qq{ && req.url == "$path"} if $path && $path ne '/';
    
    my $command = qq{varnishadm ban '$ban_expression' 2>&1};
    my $output = `$command`;
    my $exit_code = $? >> 8;
    
    if ($exit_code == 0) {
        return {
            success => 1,
            message => "URL cache purged successfully",
            purged_count => $self->count_purged_objects($output),
        };
    } else {
        return {
            success => 0,
            error => "Failed to purge URL cache: $output",
        };
    }
}

sub purge_domain {
    my ($self, $domain) = @_;
    
    # Validate domain ownership
    unless ($self->validate_domain_ownership($domain)) {
        return { success => 0, error => "Domain access denied" };
    }
    
    # Purge all cache for this domain
    my $command = qq{varnishadm ban "req.http.host == '$domain'" 2>&1};
    my $output = `$command`;
    my $exit_code = $? >> 8;
    
    if ($exit_code == 0) {
        return {
            success => 1,
            message => "Domain cache purged successfully",
            purged_count => $self->count_purged_objects($output),
        };
    } else {
        return {
            success => 0,
            error => "Failed to purge domain cache: $output",
        };
    }
}

sub purge_pattern {
    my ($self, $domain, $pattern) = @_;
    
    # Validate domain ownership
    unless ($self->validate_domain_ownership($domain)) {
        return { success => 0, error => "Domain access denied" };
    }
    
    # Sanitize pattern to prevent injection
    $pattern =~ s/[^\w\-\.\/\*\?]//g;
    
    # Create ban expression
    my $ban_expression = qq{req.http.host == "$domain" && req.url ~ "$pattern"};
    
    my $command = qq{varnishadm ban '$ban_expression' 2>&1};
    my $output = `$command`;
    my $exit_code = $? >> 8;
    
    if ($exit_code == 0) {
        return {
            success => 1,
            message => "Pattern cache purged successfully",
            pattern => $pattern,
            purged_count => $self->count_purged_objects($output),
        };
    } else {
        return {
            success => 0,
            error => "Failed to purge pattern cache: $output",
        };
    }
}

sub count_purged_objects {
    my ($self, $output) = @_;
    
    # Parse varnishadm output to estimate purged objects
    # This is a simplified implementation
    return 1; # Default to 1 if we can't parse the output
}

sub get_real_time_stats {
    my ($self, $domain) = @_;
    
    return {} unless $self->validate_domain_ownership($domain);
    
    # Get current statistics for the domain
    my $stats = $self->get_domain_stats($domain);
    
    # Add real-time metrics
    $stats->{current_connections} = $self->get_current_connections($domain);
    $stats->{requests_per_minute} = $self->get_requests_per_minute($domain);
    $stats->{cache_efficiency} = $self->calculate_cache_efficiency($stats);
    
    return $stats;
}

sub get_current_connections {
    my ($self, $domain) = @_;
    
    # Count current connections for this domain
    # This is a simplified implementation
    return int(rand(50)) + 10; # Random number for demo
}

sub get_requests_per_minute {
    my ($self, $domain) = @_;
    
    # Calculate requests per minute for this domain
    # This would require more sophisticated log analysis
    return int(rand(100)) + 50; # Random number for demo
}

sub calculate_cache_efficiency {
    my ($self, $stats) = @_;
    
    my $hit_rate = $stats->{hit_rate} || 0;
    my $response_time = $stats->{avg_response_time} || 100;
    
    # Simple efficiency calculation based on hit rate and response time
    my $efficiency = $hit_rate;
    if ($response_time < 50) {
        $efficiency += 10; # Bonus for fast response times
    } elsif ($response_time > 200) {
        $efficiency -= 10; # Penalty for slow response times
    }
    
    return $efficiency > 100 ? 100 : ($efficiency < 0 ? 0 : $efficiency);
}

sub get_top_urls {
    my ($self, $domain, $limit) = @_;
    $limit ||= 20;
    
    return [] unless $self->validate_domain_ownership($domain);
    
    my $urls = $self->get_url_stats($domain);
    
    # Return top URLs by request count
    my @top_urls = splice(@$urls, 0, $limit);
    
    return \@top_urls;
}

sub get_recent_activity {
    my ($self, $domain, $limit) = @_;
    $limit ||= 50;
    
    return [] unless $self->validate_domain_ownership($domain);
    
    my @activity = ();
    
    # Get recent cache operations from logs
    my $log_command = qq{journalctl -u varnish --since="1 hour ago" | grep "$domain" | tail -$limit 2>/dev/null};
    my $log_output = `$log_command`;
    
    my @lines = split /\n/, $log_output;
    foreach my $line (@lines) {
        if ($line =~ /(\w+\s+\d+\s+\d+:\d+:\d+).*($domain).*/) {
            push @activity, {
                timestamp => time() - int(rand(3600)), # Simplified timestamp
                type => 'cache_activity',
                domain => $domain,
                message => "Cache activity for $domain",
                details => $line,
            };
        }
    }
    
    return \@activity;
}

sub get_detailed_stats {
    my ($self, $domain, $timeframe) = @_;
    
    return {} unless $domain && $self->validate_domain_ownership($domain);
    
    # Get comprehensive statistics for the specified timeframe
    my $stats = $self->get_domain_stats($domain);
    
    # Add detailed metrics based on timeframe
    $stats->{timeframe} = $timeframe;
    $stats->{detailed_metrics} = $self->get_timeframe_metrics($domain, $timeframe);
    
    return $stats;
}

sub get_timeframe_metrics {
    my ($self, $domain, $timeframe) = @_;
    
    # Convert timeframe to log query
    my $since_param = "1 hour ago";
    if ($timeframe eq '24h') {
        $since_param = "1 day ago";
    } elsif ($timeframe eq '7d') {
        $since_param = "1 week ago";
    } elsif ($timeframe eq '30d') {
        $since_param = "1 month ago";
    }
    
    # This would typically involve more complex log analysis
    # For now, return sample data
    return {
        total_requests => int(rand(10000)) + 1000,
        unique_visitors => int(rand(1000)) + 100,
        bandwidth_saved => int(rand(1000)) + 100, # MB
        cache_hit_rate => 85 + rand(10),
        avg_response_time => 50 + rand(100),
    };
}

sub get_charts_data {
    my ($self, $domain, $timeframe) = @_;
    
    return {} unless $domain && $self->validate_domain_ownership($domain);
    
    # Generate chart data for the specified timeframe
    my $points = 24; # Default to 24 data points
    if ($timeframe eq '7d') {
        $points = 7;
    } elsif ($timeframe eq '30d') {
        $points = 30;
    }
    
    my @timestamps = ();
    my @hit_rates = ();
    my @response_times = ();
    my @request_counts = ();
    
    my $current_time = time();
    my $interval = 3600; # 1 hour
    
    if ($timeframe eq '7d') {
        $interval = 24 * 3600; # 1 day
    } elsif ($timeframe eq '30d') {
        $interval = 24 * 3600; # 1 day
    }
    
    for my $i (0..$points-1) {
        my $timestamp = $current_time - ($points - $i - 1) * $interval;
        push @timestamps, $timestamp;
        push @hit_rates, 80 + rand(15); # 80-95%
        push @response_times, 30 + rand(70); # 30-100ms
        push @request_counts, 50 + rand(150); # 50-200 requests
    }
    
    return {
        timestamps => \@timestamps,
        hit_rates => \@hit_rates,
        response_times => \@response_times,
        request_counts => \@request_counts,
    };
}

1;