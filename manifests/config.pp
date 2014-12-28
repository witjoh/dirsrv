#
# == Class: dirsrv::config
#
# Manage base configuration of dirsrv. Currently post-install configuration 
# support is very limited/non-existent.
#
class dirsrv::config
(
    $serveridentifier,
    $ldap_proto,
    $ldap_port,
    $suffix,
    $rootdn,
    $rootdn_pwd,
    $config_directory_ldap_url,
    $config_directory_admin_id,
    $config_directory_admin_pwd,
    $admin_bind_ip,
    $admin_port,
    $server_admin_id,
    $server_admin_pwd,
    $allow_anonymous_access

) inherits dirsrv::params
{

    # If bind address for the Admin interface is not given, use one generated by 
    # a DNS lookup on puppetmaster. Puppet's ipaddress facts are not used 
    # because they're even more unreliable than DNS lookups in many cases.
    if $admin_bind_ip == '' {
        $server_ip_address = generate("/usr/local/bin/getip.sh", "-4", "$fqdn")
    } else {
        $server_ip_address = $admin_bind_ip
    }

    $silent_install_inf = "${::dirsrv::params::config_dir}/silent-install.inf"

    # Copy over the inf file that drives silent installs
    file { 'dirsrv-silent-install.inf':
        name => "${silent_install_inf}",
        content => template('dirsrv/silent-install.inf.erb'),
        ensure => present,
        owner => root,
        group => root,
        mode => 600,
        require => Class['dirsrv::install'],
    }

    # Run the silent install
    exec { 'dirsrv-setup-ds-admin':
        command => "setup-ds-admin -s -f ${silent_install_inf}",
        creates => "${::dirsrv::params::config_dir}/slapd-${serveridentifier}",
        path => [ '/bin', '/sbin', '/usr/bin', '/usr/sbin' ],
        require => File['dirsrv-silent-install.inf'],
    }

    # Configure anonymous access
    ldap_entry { 'cn=config':
        ensure      => present,
        host        => 'localhost',
        port        => $ldap_port,
        username    => $rootdn,
        password    => $rootdn_pwd,
        ssl         => false,
        attributes  => { nsslapd-allow-anonymous-access => $allow_anonymous_access },
        require     => Exec['dirsrv-setup-ds-admin'],
        notify      => Class['dirsrv::service'],
    }

    class { 'dirsrv::config::backup':
        rootdn_pwd => $rootdn_pwd,        
    }
}
