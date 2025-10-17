package HitchManager;

# HitchManager.pm - Hitch SSL proxy management module
# Handles Hitch SSL proxy configuration, certificate management, and operations

use strict;
use warnings;
use File::Slurp;
use JSON;
use File::Find;

sub new {
    my $class = shift;
    my %args = @_;
    
    my $self = {
        config_file => $args{config_file} || '/etc/hitch/hitch.conf',
        service_name => $args{service_name} || 'hitch',
        cert_dir => $args{cert_dir} || '/etc/pki/tls/private',
        backend_host => $args{backend_host} || '127.0.0.1',
        backend_port => $args{backend_port} || '4443',
        frontend_port => $args{frontend_port} || '443',
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
        certificate_count => $self->count_certificates(),
        backend_connection => $self->test_backend_connection(),
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
    
    my $version = `hitch --version 2>&1 | head -1`;
    chomp $version;
    
    if ($version =~ /hitch (\d+\.\d+\.\d+)/) {
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
    
    # Test Hitch configuration
    my $output = `hitch --config=$self->{config_file} --test 2>&1`;
    my $exit_code = $? >> 8;
    
    return $exit_code == 0;
}

sub count_certificates {
    my $self = shift;
    
    my $count = 0;
    
    # Count PEM files in certificate directory
    if (-d $self->{cert_dir}) {
        opendir(my $dh, $self->{cert_dir}) or return 0;
        while (readdir $dh) {
            $count++ if /\.pem$/i;
        }
        closedir $dh;
    }
    
    # Also check for certificates listed in config file
    if (-f $self->{config_file}) {
        my $config = read_file($self->{config_file});
        my @pem_files = $config =~ /pem-file\s*=\s*"([^"]+)"/g;
        $count += scalar @pem_files;
    }
    
    return $count;
}

sub test_backend_connection {
    my $self = shift;
    
    # Test connection to Varnish backend
    my $test_command = "nc -z $self->{backend_host} $self->{backend_port}";
    my $output = `$test_command 2>&1`;
    my $exit_code = $? >> 8;
    
    return $exit_code == 0;
}

sub get_stats {
    my $self = shift;
    
    my $stats = {
        active_connections => $self->get_active_connections(),
        total_connections => $self->get_total_connections(),
        ssl_handshakes => $self->get_ssl_handshakes(),
        bytes_transferred => $self->get_bytes_transferred(),
        certificate_errors => $self->get_certificate_errors(),
        backend_failures => $self->get_backend_failures(),
    };
    
    return $stats;
}

sub get_active_connections {
    my $self = shift;
    
    # Count active connections using netstat
    my $output = `netstat -an | grep ":$self->{frontend_port} " | grep ESTABLISHED | wc -l 2>/dev/null`;
    chomp $output;
    
    return $output || 0;
}

sub get_total_connections {
    my $self = shift;
    
    # Get connection count from logs (simplified)
    my $log_count = `journalctl -u $self->{service_name} --since="1 hour ago" | grep -c "connection" 2>/dev/null`;
    chomp $log_count;
    
    return $log_count || 0;
}

sub get_ssl_handshakes {
    my $self = shift;
    
    # Count SSL handshakes from logs
    my $handshake_count = `journalctl -u $self->{service_name} --since="1 hour ago" | grep -c "SSL handshake" 2>/dev/null`;
    chomp $handshake_count;
    
    return $handshake_count || 0;
}

sub get_bytes_transferred {
    my $self = shift;
    
    # This would typically require more detailed logging
    # Return placeholder value
    return {
        sent => 0,
        received => 0,
    };
}

sub get_certificate_errors {
    my $self = shift;
    
    # Count certificate-related errors from logs
    my $error_count = `journalctl -u $self->{service_name} --since="1 day ago" | grep -c -i "certificate.*error" 2>/dev/null`;
    chomp $error_count;
    
    return $error_count || 0;
}

sub get_backend_failures {
    my $self = shift;
    
    # Count backend connection failures
    my $failure_count = `journalctl -u $self->{service_name} --since="1 day ago" | grep -c "backend.*fail" 2>/dev/null`;
    chomp $failure_count;
    
    return $failure_count || 0;
}

sub restart_service {
    my $self = shift;
    
    my $output = `systemctl restart $self->{service_name} 2>&1`;
    my $exit_code = $? >> 8;
    
    if ($exit_code == 0) {
        return {
            success => 1,
            message => "Hitch service restarted successfully",
        };
    } else {
        return {
            success => 0,
            message => "Failed to restart Hitch service: $output",
        };
    }
}

sub get_config {
    my $self = shift;
    
    my $config = {};
    
    if (-f $self->{config_file}) {
        my $content = read_file($self->{config_file});
        
        # Parse Hitch configuration
        $config->{content} = $content;
        
        # Extract key settings
        if ($content =~ /backend\s*=\s*"([^"]+)"/) {
            $config->{backend} = $1;
        }
        
        if ($content =~ /frontend\s*=\s*"([^"]+)"/) {
            $config->{frontend} = $1;
        }
        
        # Get certificate files
        my @pem_files = $content =~ /pem-file\s*=\s*"([^"]+)"/g;
        $config->{certificates} = \@pem_files;
        
        # Get other settings
        $config->{workers} = $1 if $content =~ /workers\s*=\s*(\d+)/;
        $config->{ciphers} = $1 if $content =~ /ciphers\s*=\s*"([^"]+)"/;
    }
    
    return $config;
}

sub save_config {
    my ($self, $config) = @_;
    
    eval {
        if ($config->{content}) {
            # Backup existing configuration
            my $backup_file = $self->{config_file} . '.backup.' . time();
            if (-f $self->{config_file}) {
                system("cp '$self->{config_file}' '$backup_file'");
            }
            
            # Write new configuration
            write_file($self->{config_file}, $config->{content});
            
            # Validate configuration
            unless ($self->validate_config()) {
                # Restore backup if validation fails
                if (-f $backup_file) {
                    system("cp '$backup_file' '$self->{config_file}'");
                }
                die "Invalid Hitch configuration";
            }
        }
        
        return { success => 1, message => "Hitch configuration saved successfully" };
    };
    if ($@) {
        return { success => 0, error => "Failed to save Hitch configuration: $@" };
    }
}

sub configure {
    my ($self, $config) = @_;
    
    my $hitch_config = $self->generate_config($config);
    
    eval {
        # Write Hitch configuration
        write_file($self->{config_file}, $hitch_config);
        
        # Validate configuration
        unless ($self->validate_config()) {
            die "Generated Hitch configuration is invalid";
        }
        
        return { success => 1, message => "Hitch configured successfully" };
    };
    if ($@) {
        return { success => 0, error => "Failed to configure Hitch: $@" };
    }
}

sub generate_config {
    my ($self, $config) = @_;
    
    my $backend_host = $config->{backend_host} || $self->{backend_host};
    my $backend_port = $config->{backend_port} || $self->{backend_port};
    my $frontend_port = $config->{frontend_port} || $self->{frontend_port};
    
    # Get SSL certificate paths from Apache configuration
    my @cert_paths = $self->get_ssl_certificate_paths();
    
    my $hitch_config = qq{# Hitch SSL Proxy Configuration
# Generated automatically for Varnish integration

# Frontend configuration - where Hitch listens for HTTPS connections
frontend = "*:$frontend_port"

# Backend configuration - where to forward decrypted requests (Varnish)
backend = "[$backend_host]:$backend_port"

# Worker processes
workers = 4

# Daemon mode
daemon = on

# User to run as
user = "hitch"

# Group to run as  
group = "hitch"

# SSL/TLS Settings
ssl-engine = ""
prefer-server-ciphers = on

# Cipher list (secure defaults)
ciphers = "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256"

# SSL protocols
ssl-protocols = "TLSv1.2 TLSv1.3"

# Certificate files
};

    # Add certificate files
    foreach my $cert_path (@cert_paths) {
        $hitch_config .= qq{pem-file = "$cert_path"\n};
    }
    
    # If no certificates found, add placeholder
    if (@cert_paths == 0) {
        $hitch_config .= qq{# pem-file = "/path/to/certificate.pem"\n};
        $hitch_config .= qq{# Note: Please configure SSL certificates before starting Hitch\n};
    }
    
    $hitch_config .= qq{
# Additional security settings
write-timeout = 25
read-timeout = 25

# Logging
syslog = on
syslog-facility = "daemon"

# Performance tuning
backlog = 100
keepalive = 3600
};

    return $hitch_config;
}

sub get_ssl_certificate_paths {
    my $self = shift;
    
    my @cert_paths = ();
    
    # Get SSL certificate paths from Apache configuration
    my $apache_ssl_output = `grep SSLCertificateFile /etc/apache2/conf/httpd.conf 2>/dev/null | awk '{print \$2}'`;
    my @apache_certs = split /\n/, $apache_ssl_output;
    
    # Process each certificate path
    foreach my $cert_path (@apache_certs) {
        chomp $cert_path;
        next unless $cert_path && -f $cert_path;
        
        # Find corresponding key file
        my $key_path = $cert_path;
        $key_path =~ s/\.crt$/.key/;
        $key_path =~ s/\.pem$/.key/;
        
        if (-f $key_path) {
            # Create combined PEM file for Hitch
            my $combined_pem = $self->create_combined_pem($cert_path, $key_path);
            push @cert_paths, $combined_pem if $combined_pem;
        }
    }
    
    # Also check common certificate locations
    my @common_locations = (
        '/etc/ssl/certs',
        '/etc/pki/tls/certs',
        '/var/cpanel/ssl/installed/certs',
    );
    
    foreach my $location (@common_locations) {
        next unless -d $location;
        
        opendir(my $dh, $location) or next;
        while (readdir $dh) {
            next unless /\.pem$/i;
            my $full_path = "$location/$_";
            push @cert_paths, $full_path if -f $full_path;
        }
        closedir $dh;
    }
    
    # Remove duplicates
    my %seen = ();
    @cert_paths = grep { !$seen{$_}++ } @cert_paths;
    
    return @cert_paths;
}

sub create_combined_pem {
    my ($self, $cert_path, $key_path) = @_;
    
    return unless -f $cert_path && -f $key_path;
    
    # Create combined PEM file in Hitch directory
    my $cert_basename = (split '/', $cert_path)[-1];
    $cert_basename =~ s/\.(crt|pem)$//;
    my $combined_path = "/etc/hitch/certs/${cert_basename}.pem";
    
    # Ensure directory exists
    system("mkdir -p /etc/hitch/certs");
    
    eval {
        my $cert_content = read_file($cert_path);
        my $key_content = read_file($key_path);
        
        # Combine certificate and key
        my $combined_content = $key_content . "\n" . $cert_content;
        
        write_file($combined_path, $combined_content);
        
        # Set appropriate permissions
        chmod 0600, $combined_path;
        system("chown hitch:hitch '$combined_path' 2>/dev/null");
        
        return $combined_path;
    };
    if ($@) {
        warn "Failed to create combined PEM file: $@";
        return;
    }
}

sub add_certificate {
    my ($self, $cert_path, $key_path, $domain) = @_;
    
    eval {
        # Create combined PEM file
        my $combined_pem = $self->create_combined_pem($cert_path, $key_path);
        unless ($combined_pem) {
            die "Failed to create combined PEM file";
        }
        
        # Update Hitch configuration to include new certificate
        my $config = read_file($self->{config_file});
        $config .= qq{\npem-file = "$combined_pem"\n};
        
        write_file($self->{config_file}, $config);
        
        # Validate configuration
        unless ($self->validate_config()) {
            die "Configuration validation failed after adding certificate";
        }
        
        return {
            success => 1,
            message => "Certificate added successfully",
            pem_file => $combined_pem,
        };
    };
    if ($@) {
        return {
            success => 0,
            error => "Failed to add certificate: $@",
        };
    }
}

sub remove_certificate {
    my ($self, $pem_file) = @_;
    
    eval {
        # Remove certificate file from configuration
        my $config = read_file($self->{config_file});
        $config =~ s/^\s*pem-file\s*=\s*"\Q$pem_file\E"\s*\n?//gm;
        
        write_file($self->{config_file}, $config);
        
        # Remove the PEM file
        unlink $pem_file if -f $pem_file;
        
        # Validate configuration
        unless ($self->validate_config()) {
            die "Configuration validation failed after removing certificate";
        }
        
        return {
            success => 1,
            message => "Certificate removed successfully",
        };
    };
    if ($@) {
        return {
            success => 0,
            error => "Failed to remove certificate: $@",
        };
    }
}

sub list_certificates {
    my $self = shift;
    
    my @certificates = ();
    
    if (-f $self->{config_file}) {
        my $config = read_file($self->{config_file});
        my @pem_files = $config =~ /pem-file\s*=\s*"([^"]+)"/g;
        
        foreach my $pem_file (@pem_files) {
            next unless -f $pem_file;
            
            my $cert_info = $self->get_certificate_info($pem_file);
            push @certificates, {
                path => $pem_file,
                %$cert_info,
            };
        }
    }
    
    return \@certificates;
}

sub get_certificate_info {
    my ($self, $pem_file) = @_;
    
    my $info = {
        subject => 'Unknown',
        issuer => 'Unknown',
        valid_from => 'Unknown',
        valid_to => 'Unknown',
        expired => 1,
    };
    
    # Use openssl to get certificate information
    my $cert_text = `openssl x509 -in "$pem_file" -text -noout 2>/dev/null`;
    
    if ($cert_text) {
        # Extract subject
        if ($cert_text =~ /Subject:.*CN\s*=\s*([^,\n]+)/) {
            $info->{subject} = $1;
        }
        
        # Extract issuer
        if ($cert_text =~ /Issuer:.*CN\s*=\s*([^,\n]+)/) {
            $info->{issuer} = $1;
        }
        
        # Extract validity dates
        if ($cert_text =~ /Not Before:\s*(.+)/) {
            $info->{valid_from} = $1;
        }
        
        if ($cert_text =~ /Not After\s*:\s*(.+)/) {
            $info->{valid_to} = $1;
        }
        
        # Check if certificate is expired
        my $check_output = `openssl x509 -in "$pem_file" -checkend 0 2>/dev/null`;
        $info->{expired} = $? >> 8;
    }
    
    return $info;
}

sub get_recent_logs {
    my ($self, $limit) = @_;
    $limit ||= 100;
    
    my @logs = ();
    
    # Get recent Hitch logs
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
                source => 'hitch',
            };
        };
    }
    
    return \@logs;
}

1;