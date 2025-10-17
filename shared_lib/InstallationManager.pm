package InstallationManager;

# InstallationManager.pm - Automated installation manager for Varnish and Hitch
# Implements the manual installation steps from the installation instructions

use strict;
use warnings;
use File::Slurp;
use JSON;

sub new {
    my $class = shift;
    my %args = @_;
    
    my $self = {
        log_file => $args{log_file} || '/var/log/varnish_hitch_install.log',
        apache_port => $args{apache_port} || '8080',
        apache_ssl_port => $args{apache_ssl_port} || '8443',
        varnish_port => $args{varnish_port} || '80',
        hitch_port => $args{hitch_port} || '443',
        hitch_backend_port => $args{hitch_backend_port} || '4443',
    };
    
    bless $self, $class;
    return $self;
}

sub install {
    my ($self, $install_type) = @_;
    $install_type ||= 'full';
    
    $self->log("Starting installation: $install_type");
    
    my $result = {
        success => 0,
        message => '',
        steps => [],
        errors => [],
    };
    
    eval {
        # Step 1: System preparation
        $self->log("Step 1: System preparation");
        $self->prepare_system();
        push @{$result->{steps}}, "System preparation completed";
        
        if ($install_type eq 'full' || $install_type eq 'varnish') {
            # Step 2: Install Varnish
            $self->log("Step 2: Installing Varnish");
            $self->install_varnish();
            push @{$result->{steps}}, "Varnish installation completed";
        }
        
        if ($install_type eq 'full' || $install_type eq 'hitch') {
            # Step 3: Install Hitch
            $self->log("Step 3: Installing Hitch");
            $self->install_hitch();
            push @{$result->{steps}}, "Hitch installation completed";
        }
        
        if ($install_type eq 'full' || $install_type eq 'update') {
            # Step 4: Configure Apache ports
            $self->log("Step 4: Configuring Apache ports");
            $self->configure_apache_ports();
            push @{$result->{steps}}, "Apache port configuration completed";
            
            # Step 5: Configure Varnish
            $self->log("Step 5: Configuring Varnish");
            $self->configure_varnish();
            push @{$result->{steps}}, "Varnish configuration completed";
            
            # Step 6: Configure Hitch
            $self->log("Step 6: Configuring Hitch");
            $self->configure_hitch();
            push @{$result->{steps}}, "Hitch configuration completed";
            
            # Step 7: Start services
            $self->log("Step 7: Starting services");
            $self->start_services();
            push @{$result->{steps}}, "Services started successfully";
        }
        
        $result->{success} = 1;
        $result->{message} = "Installation completed successfully";
        $self->log("Installation completed successfully");
        
    };
    if ($@) {
        my $error = $@;
        $result->{success} = 0;
        $result->{message} = "Installation failed: $error";
        push @{$result->{errors}}, $error;
        $self->log("Installation failed: $error");
    }
    
    return $result;
}

sub prepare_system {
    my $self = shift;
    
    # Update system packages
    $self->log("Updating system packages");
    my $update_output = `dnf update -y 2>&1`;
    if ($? != 0) {
        die "Failed to update system packages: $update_output";
    }
    
    # Check if we're on a supported system
    my $os_release = read_file('/etc/os-release');
    unless ($os_release =~ /centos|rhel|rocky|alma/i) {
        $self->log("Warning: This installer is designed for RHEL/CentOS systems");
    }
    
    # Backup important configuration files
    $self->backup_configurations();
    
    $self->log("System preparation completed");
}

sub backup_configurations {
    my $self = shift;
    
    my $backup_dir = "/root/varnish_hitch_backup_" . time();
    system("mkdir -p $backup_dir");
    
    # Backup cPanel configuration
    if (-f '/var/cpanel/cpanel.config') {
        system("cp /var/cpanel/cpanel.config $backup_dir/cpanel.config.backup");
        $self->log("Backed up cPanel configuration");
    }
    
    # Backup Apache configuration
    if (-d '/etc/apache2/conf') {
        system("cp -r /etc/apache2/conf $backup_dir/apache_conf.backup");
        $self->log("Backed up Apache configuration");
    }
    
    # Backup existing Varnish configuration if it exists
    if (-f '/etc/varnish/default.vcl') {
        system("cp /etc/varnish/default.vcl $backup_dir/varnish_default.vcl.backup");
        $self->log("Backed up existing Varnish configuration");
    }
    
    # Backup existing Hitch configuration if it exists
    if (-f '/etc/hitch/hitch.conf') {
        system("cp /etc/hitch/hitch.conf $backup_dir/hitch.conf.backup");
        $self->log("Backed up existing Hitch configuration");
    }
    
    $self->log("Configuration backups stored in: $backup_dir");
}

sub install_varnish {
    my $self = shift;
    
    # Add Varnish 7.5 repository
    $self->log("Adding Varnish 7.5 repository");
    my $repo_output = `curl -s https://packagecloud.io/install/repositories/varnishcache/varnish75/script.rpm.sh | bash 2>&1`;
    if ($? != 0) {
        die "Failed to add Varnish repository: $repo_output";
    }
    
    # Install Varnish
    $self->log("Installing Varnish package");
    my $install_output = `dnf install varnish -y 2>&1`;
    if ($? != 0) {
        die "Failed to install Varnish: $install_output";
    }
    
    # Enable Varnish service
    system("systemctl enable varnish");
    
    $self->log("Varnish installation completed");
}

sub install_hitch {
    my $self = shift;
    
    # Install Hitch
    $self->log("Installing Hitch package");
    my $install_output = `dnf install hitch -y 2>&1`;
    if ($? != 0) {
        die "Failed to install Hitch: $install_output";
    }
    
    # Create hitch user and group if they don't exist
    system("getent group hitch >/dev/null || groupadd hitch");
    system("getent passwd hitch >/dev/null || useradd -g hitch -s /sbin/nologin -d /var/lib/hitch hitch");
    
    # Create necessary directories
    system("mkdir -p /etc/hitch/certs");
    system("mkdir -p /var/lib/hitch");
    system("chown -R hitch:hitch /var/lib/hitch");
    system("chown -R hitch:hitch /etc/hitch/certs");
    system("chmod 700 /etc/hitch/certs");
    
    # Enable Hitch service
    system("systemctl enable hitch");
    
    $self->log("Hitch installation completed");
}

sub configure_apache_ports {
    my $self = shift;
    
    # Backup current cPanel configuration
    if (-f '/var/cpanel/cpanel.config') {
        system("cp -a /var/cpanel/cpanel.config /var/cpanel/cpanel.config-backup");
        
        # Read and modify cPanel configuration
        my $cpanel_config = read_file('/var/cpanel/cpanel.config');
        
        # Update Apache ports
        $cpanel_config =~ s/^apache_port=.*$/apache_port=0.0.0.0:$self->{apache_port}/gm;
        $cpanel_config =~ s/^apache_ssl_port=.*$/apache_ssl_port=0.0.0.0:$self->{apache_ssl_port}/gm;
        
        # If ports don't exist, add them
        unless ($cpanel_config =~ /^apache_port=/m) {
            $cpanel_config .= "\napache_port=0.0.0.0:$self->{apache_port}\n";
        }
        unless ($cpanel_config =~ /^apache_ssl_port=/m) {
            $cpanel_config .= "\napache_ssl_port=0.0.0.0:$self->{apache_ssl_port}\n";
        }
        
        write_file('/var/cpanel/cpanel.config', $cpanel_config);
        $self->log("Updated cPanel configuration with new Apache ports");
        
        # Rebuild Apache configuration
        $self->log("Rebuilding Apache configuration");
        my $rebuild_output = `/scripts/rebuildhttpdconf 2>&1`;
        if ($? != 0) {
            $self->log("Warning: Apache configuration rebuild had issues: $rebuild_output");
        }
        
        # Restart Apache
        $self->log("Restarting Apache");
        system("/scripts/restartsrv_httpd");
        
    } else {
        $self->log("Warning: cPanel configuration file not found, skipping Apache port configuration");
    }
}

sub configure_varnish {
    my $self = shift;
    
    # Generate VCL configuration
    my $vcl_config = $self->generate_varnish_vcl();
    
    # Write VCL configuration
    write_file('/etc/varnish/default.vcl', $vcl_config);
    $self->log("Created Varnish VCL configuration");
    
    # Configure Varnish service
    $self->configure_varnish_service();
    
    $self->log("Varnish configuration completed");
}

sub generate_varnish_vcl {
    my $self = shift;
    
    my $vcl = qq{vcl 4.1;

import proxy;

backend default {
    .host = "127.0.0.1";
    .port = "$self->{apache_port}";
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
        req.url ~ "\\\\?.*" ||
        req.url ~ "preview=true" ||
        req.url ~ "xmlrpc.php") {
        return(pass);
    }
    
    # Don't cache cPanel and WHM
    if (req.url ~ "^/(cpanel|whm|webmail)" ||
        req.http.host ~ "(cpanel|whm|webmail)") {
        return(pass);
    }
    
    # Remove WordPress cookies for static content
    if (req.url ~ "\\\\.(css|js|png|gif|jp(e)?g|swf|ico|woff|woff2|ttf|eot|svg)\$") {
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
    if (bereq.url ~ "\\\\.(css|js|png|gif|jp(e)?g|swf|ico|woff|woff2|ttf|eot|svg)\$") {
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
    
    # Remove backend server information for security
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
    # Add your server's IP addresses here
}
};

    return $vcl;
}

sub configure_varnish_service {
    my $self = shift;
    
    # Copy and modify Varnish service file
    system("cp /usr/lib/systemd/system/varnish.service /etc/systemd/system/");
    
    # Read service file
    my $service_content = read_file('/etc/systemd/system/varnish.service');
    
    # Update ExecStart line
    my $exec_start = "ExecStart=/usr/sbin/varnishd -a :$self->{varnish_port} -a 127.0.0.1:$self->{hitch_backend_port},proxy -f /etc/varnish/default.vcl -s malloc,256m";
    
    $service_content =~ s/^ExecStart=.*$/$exec_start/gm;
    
    # Write updated service file
    write_file('/etc/systemd/system/varnish.service', $service_content);
    
    # Reload systemd
    system("systemctl daemon-reload");
    
    $self->log("Configured Varnish service");
}

sub configure_hitch {
    my $self = shift;
    
    # Get SSL certificate paths
    my @cert_paths = $self->get_ssl_certificates();
    
    # Generate Hitch configuration
    my $hitch_config = $self->generate_hitch_config(@cert_paths);
    
    # Write Hitch configuration
    write_file('/etc/hitch/hitch.conf', $hitch_config);
    $self->log("Created Hitch configuration");
    
    # Create combined PEM files for certificates
    $self->create_combined_certificates(@cert_paths);
    
    $self->log("Hitch configuration completed");
}

sub get_ssl_certificates {
    my $self = shift;
    
    my @cert_paths = ();
    
    # Get SSL certificate paths from Apache configuration
    my $ssl_cert_output = `grep SSLCertificateFile /etc/apache2/conf/httpd.conf 2>/dev/null | awk '{print \$2}'`;
    my @apache_certs = split /\n/, $ssl_cert_output;
    
    foreach my $cert_path (@apache_certs) {
        chomp $cert_path;
        next unless $cert_path && -f $cert_path;
        push @cert_paths, $cert_path;
    }
    
    # Also check common certificate locations
    my @common_locations = (
        '/var/cpanel/ssl/installed/certs',
        '/etc/ssl/certs',
        '/etc/pki/tls/certs',
    );
    
    foreach my $location (@common_locations) {
        next unless -d $location;
        
        opendir(my $dh, $location) or next;
        while (readdir $dh) {
            next unless /\.(crt|pem)$/i;
            my $full_path = "$location/$_";
            push @cert_paths, $full_path if -f $full_path;
        }
        closedir $dh;
    }
    
    # Remove duplicates
    my %seen = ();
    @cert_paths = grep { !$seen{$_}++ } @cert_paths;
    
    $self->log("Found " . scalar(@cert_paths) . " SSL certificates");
    
    return @cert_paths;
}

sub generate_hitch_config {
    my ($self, @cert_paths) = @_;
    
    my $config = qq{# Hitch SSL Proxy Configuration
# Generated automatically for Varnish integration

# Frontend configuration - where Hitch listens for HTTPS connections
frontend = "*:$self->{hitch_port}"

# Backend configuration - where to forward decrypted requests (Varnish)
backend = "[127.0.0.1]:$self->{hitch_backend_port}"

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
        my $pem_file = $self->get_combined_pem_path($cert_path);
        $config .= qq{pem-file = "$pem_file"\n};
    }
    
    # If no certificates found, add placeholder
    if (@cert_paths == 0) {
        $config .= qq{# pem-file = "/etc/hitch/certs/example.pem"\n};
        $config .= qq{# Note: Please configure SSL certificates before starting Hitch\n};
    }
    
    $config .= qq{
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

    return $config;
}

sub create_combined_certificates {
    my ($self, @cert_paths) = @_;
    
    foreach my $cert_path (@cert_paths) {
        my $key_path = $cert_path;
        $key_path =~ s/\.crt$/.key/;
        $key_path =~ s/\.pem$/.key/;
        
        # Try to find the corresponding key file
        unless (-f $key_path) {
            # Look for key file with same name in different directory
            my $cert_basename = (split '/', $cert_path)[-1];
            $cert_basename =~ s/\.(crt|pem)$//;
            
            my @key_locations = (
                '/var/cpanel/ssl/installed/keys',
                '/etc/ssl/private',
                '/etc/pki/tls/private',
            );
            
            foreach my $location (@key_locations) {
                my $potential_key = "$location/${cert_basename}.key";
                if (-f $potential_key) {
                    $key_path = $potential_key;
                    last;
                }
            }
        }
        
        if (-f $key_path) {
            $self->create_combined_pem($cert_path, $key_path);
        } else {
            $self->log("Warning: Could not find key file for certificate: $cert_path");
        }
    }
}

sub create_combined_pem {
    my ($self, $cert_path, $key_path) = @_;
    
    return unless -f $cert_path && -f $key_path;
    
    my $cert_basename = (split '/', $cert_path)[-1];
    $cert_basename =~ s/\.(crt|pem)$//;
    my $combined_path = "/etc/hitch/certs/${cert_basename}.pem";
    
    eval {
        my $cert_content = read_file($cert_path);
        my $key_content = read_file($key_path);
        
        # Combine key and certificate (key first for Hitch)
        my $combined_content = $key_content . "\n" . $cert_content;
        
        write_file($combined_path, $combined_content);
        
        # Set appropriate permissions
        chmod 0600, $combined_path;
        system("chown hitch:hitch '$combined_path' 2>/dev/null");
        
        $self->log("Created combined PEM file: $combined_path");
        
        return $combined_path;
    };
    if ($@) {
        $self->log("Warning: Failed to create combined PEM file for $cert_path: $@");
        return;
    }
}

sub get_combined_pem_path {
    my ($self, $cert_path) = @_;
    
    my $cert_basename = (split '/', $cert_path)[-1];
    $cert_basename =~ s/\.(crt|pem)$//;
    
    return "/etc/hitch/certs/${cert_basename}.pem";
}

sub start_services {
    my $self = shift;
    
    # Stop services first
    $self->log("Stopping services");
    system("systemctl stop varnish hitch 2>/dev/null");
    
    # Start Varnish first
    $self->log("Starting Varnish");
    my $varnish_output = `systemctl start varnish 2>&1`;
    if ($? != 0) {
        $self->log("Failed to start Varnish: $varnish_output");
        $self->log("Attempting Varnish diagnostics...");
        $self->diagnose_varnish_failure();
        
        # Try to start again with a longer timeout
        $self->log("Retrying Varnish startup...");
        system("systemctl daemon-reload");
        sleep 5;
        $varnish_output = `timeout 60 systemctl start varnish 2>&1`;
        if ($? != 0) {
            $self->log("ERROR: Varnish failed to start after retry: $varnish_output");
            $self->log("Continuing with installation - Varnish can be started manually later");
        } else {
            $self->log("Varnish started successfully on retry");
        }
    }
    
    # Wait a moment for Varnish to start
    sleep 2;
    
    # Test Hitch configuration
    $self->log("Testing Hitch configuration");
    my $hitch_test = `hitch --config=/etc/hitch/hitch.conf --test 2>&1`;
    if ($? != 0) {
        $self->log("Warning: Hitch configuration test failed: $hitch_test");
        $self->log("Hitch will not be started due to configuration issues");
    } else {
        # Start Hitch
        $self->log("Starting Hitch");
        my $hitch_output = `systemctl start hitch 2>&1`;
        if ($? != 0) {
            $self->log("Warning: Failed to start Hitch: $hitch_output");
        }
    }
    
    # Restart Apache to ensure it's using the new ports
    $self->log("Restarting Apache with new configuration");
    system("systemctl restart httpd");
    
    # Enable services for auto-start
    system("systemctl enable varnish hitch");
    
    # Wait and check service status
    sleep 3;
    $self->check_service_status();
    
    $self->log("Service startup completed");
}

sub diagnose_varnish_failure {
    my $self = shift;
    
    # Check VCL syntax
    $self->log("Checking VCL syntax");
    my $vcl_check = `varnishd -C -f /etc/varnish/default.vcl 2>&1`;
    if ($? != 0) {
        $self->log("VCL syntax error: $vcl_check");
    } else {
        $self->log("VCL syntax is valid");
    }
    
    # Check port conflicts
    $self->log("Checking for port conflicts");
    my $port_check = `netstat -tlnp | grep :80`;
    if ($port_check) {
        $self->log("Port 80 conflicts found: $port_check");
    } else {
        $self->log("Port 80 is available");
    }
    
    # Check systemd journal
    $self->log("Checking systemd journal for Varnish errors");
    my $journal = `journalctl -u varnish --no-pager -n 20 2>&1`;
    $self->log("Varnish journal: $journal");
    
    # Check file permissions
    $self->log("Checking Varnish file permissions");
    my $perms = `ls -la /etc/varnish/ /var/lib/varnish/ 2>&1`;
    $self->log("Varnish permissions: $perms");
}

sub check_service_status {
    my $self = shift;
    
    $self->log("=== Service Status Check ===");
    
    # Check Varnish
    my $varnish_status = `systemctl is-active varnish 2>/dev/null`;
    chomp $varnish_status;
    if ($varnish_status eq 'active') {
        $self->log("✓ Varnish: RUNNING");
    } else {
        $self->log("✗ Varnish: $varnish_status");
        $self->log("  Troubleshoot: systemctl status varnish");
        $self->log("  Logs: journalctl -u varnish -f");
    }
    
    # Check Hitch
    my $hitch_status = `systemctl is-active hitch 2>/dev/null`;
    chomp $hitch_status;
    if ($hitch_status eq 'active') {
        $self->log("✓ Hitch: RUNNING");
    } else {
        $self->log("✗ Hitch: $hitch_status");
        $self->log("  Troubleshoot: systemctl status hitch");
        $self->log("  Logs: journalctl -u hitch -f");
    }
    
    # Check Apache
    my $apache_status = `systemctl is-active httpd 2>/dev/null`;
    chomp $apache_status;
    if ($apache_status eq 'active') {
        $self->log("✓ Apache: RUNNING");
    } else {
        $self->log("✗ Apache: $apache_status");
        $self->log("  Troubleshoot: systemctl status httpd");
    }
    
    # Check if ports are listening
    $self->log("=== Port Status ===");
    my $port80 = `netstat -tlnp 2>/dev/null | grep ":80 "`;
    my $port443 = `netstat -tlnp 2>/dev/null | grep ":443 "`;
    my $port8080 = `netstat -tlnp 2>/dev/null | grep ":8080 "`;
    my $port8443 = `netstat -tlnp 2>/dev/null | grep ":8443 "`;
    
    $port80 ? $self->log("✓ Port 80: $port80") : $self->log("✗ Port 80: Not listening");
    $port443 ? $self->log("✓ Port 443: $port443") : $self->log("✗ Port 443: Not listening");
    $port8080 ? $self->log("✓ Port 8080: $port8080") : $self->log("✗ Port 8080: Not listening");
    $port8443 ? $self->log("✓ Port 8443: $port8443") : $self->log("✗ Port 8443: Not listening");
    
    # Provide recovery instructions
    if ($varnish_status ne 'active' || $hitch_status ne 'active') {
        $self->log("=== Recovery Instructions ===");
        if ($varnish_status ne 'active') {
            $self->log("To fix Varnish:");
            $self->log("  1. Check configuration: varnishd -C -f /etc/varnish/default.vcl");
            $self->log("  2. Start manually: systemctl start varnish");
            $self->log("  3. Check logs: journalctl -u varnish");
        }
        if ($hitch_status ne 'active') {
            $self->log("To fix Hitch:");
            $self->log("  1. Test configuration: hitch --config=/etc/hitch/hitch.conf --test");
            $self->log("  2. Start manually: systemctl start hitch");
            $self->log("  3. Check logs: journalctl -u hitch");
        }
    }
}

sub log {
    my ($self, $message) = @_;
    
    my $timestamp = scalar localtime();
    my $log_entry = "[$timestamp] $message\n";
    
    # Append to log file
    if (open my $fh, '>>', $self->{log_file}) {
        print $fh $log_entry;
        close $fh;
    }
    
    # Also print to STDERR for immediate feedback
    print STDERR $log_entry;
}

1;