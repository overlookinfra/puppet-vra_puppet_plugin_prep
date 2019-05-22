# vra_puppet_plugin_prep
#
# A description of what this class does
#
# @summary Prepares a PE master for vRA Puppet Plugin integration.
#
# @example
#   include vra_puppet_plugin_prep
#
# @example
#   class { 'vra_puppet_plugin_prep':
#     vro_plugin_user    => 'vro-plugin-user',
#     vro_password       => 'puppetlabs',
#     vro_password_hash  => '$1$Fq9vkV1h$4oMRtIjjjAhi6XQVSH6.Y.',
#     manage_autosign    => true,
#     autosign_secret    => 'S3cr3tP@ssw0rd!',
#   }
class vra_puppet_plugin_prep (
  String  $vro_plugin_user,
  String  $vro_password,
  String  $vro_password_hash,
  Boolean $manage_autosign,
  Boolean $manage_localuser,
  String  $autosign_secret,
  String  $vro_email,
  String  $vro_display_name,
) {

  $vro_role_name = 'VRO Plugin User'
  $permissions   = [
    { 'object_type' => 'cert_requests',
      'action'      => 'accept_reject',
      'instance'    => '*',
    },
    { 'object_type' => 'tasks',
      'action'      => 'run',
      'instance'    => '*',
    },
    { 'object_type' => 'nodes',
      'action'      => 'view_data',
      'instance'    => '*',
    },
    { 'object_type' => 'orchestrator',
      'action'      => 'view',
      'instance'    => '*',
    },
    { 'object_type' => 'puppet_agent',
      'action'      => 'run',
      'instance'    => '*',
    },
  ]

  rbac_role { $vro_role_name:
    ensure      => present,
    name        => $vro_role_name,
    description => $vro_role_name,
    permissions => $permissions,
  }

  rbac_user { $vro_plugin_user:
    ensure       => 'present',
    name         => $vro_plugin_user,
    display_name => $vro_display_name,
    password     => $vro_password,
    roles        => [ $vro_role_name ],
    email        => $vro_email,
    require      => Rbac_role[$vro_role_name],
  }

  if $manage_localuser {
    user { $vro_plugin_user:
      ensure     => present,
      shell      => '/bin/bash',
      password   => $vro_password_hash,
      managehome => true,
    }
  }

  file { '/etc/sudoers.d/vro-plugin-user':
    ensure  => file,
    mode    => '0440',
    owner   => 'root',
    group   => 'root',
    content => epp('vra_puppet_plugin_prep/vro_sudoer_file.epp', { 'vro_plugin_user' => $vro_plugin_user }),
  }

  sshd_config { 'PasswordAuthentication':
    ensure => present,
    value  => 'yes',
  }

  sshd_config { 'ChallengeResponseAuthentication':
    ensure => present,
    value  => 'no',
  }

  package { 'rgen':
    ensure   => latest,
    provider => puppet_gem,
  }

  package { 'puppet-strings':
    ensure   => latest,
    provider => puppet_gem,
  }

  if $manage_autosign {
    file { '/etc/puppetlabs/puppet/autosign.rb' :
      ensure  => file,
      owner   => 'pe-puppet',
      group   => 'pe-puppet',
      mode    => '0700',
      content => epp('vra_puppet_plugin_prep/autosign.rb.epp', { 'autosign_secret' => $autosign_secret }),
      notify  => Service['pe-puppetserver'],
    }

    ini_setting { 'autosign script setting':
      ensure  => present,
      path    => '/etc/puppetlabs/puppet/puppet.conf',
      section => 'master',
      setting => 'autosign',
      value   => '/etc/puppetlabs/puppet/autosign.rb',
      notify  => Service['pe-puppetserver'],
    }
  }
}

