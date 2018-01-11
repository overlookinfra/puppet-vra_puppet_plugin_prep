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
  # Array  $environments      = [ 'production', 'development', ],
  # Array  $roles             = [ 'role::generic', ],
  String  $vro_plugin_user   = 'vro-plugin-user',
  String  $vro_password      = 'puppetlabs',
  String  $vro_password_hash = '$1$Fq9vkV1h$4oMRtIjjjAhi6XQVSH6.Y.', #puppetlabs
  Boolean $manage_autosign   = true,
  String  $autosign_secret   = 'S3cr3tP@ssw0rd!',
) {

  # node_group { 'Roles':
  #   ensure               => 'present',
  #   classes              => {},
  #   environment          => 'production',
  #   override_environment => 'false',
  #   parent               => 'All Nodes',
  #   rule                 => [],
  # }

  $vro_role_name = 'VRO Plugin User'
  $permissions   = [
    { 'action'      => 'view_data',
      'instance'    => '*',
      'object_type' => 'nodes',
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
    display_name => 'vRO Puppet Plugin',
    password     => $vro_password,
    roles        => [ $vro_role_name ],
    require      => Rbac_role[$vro_role_name],
  }

  user { $vro_plugin_user:
    ensure     => present,
    shell      => '/bin/bash',
    password   => $vro_password_hash,
    groups     => ['pe-puppet'],
    managehome => true,
  }

  file { '/etc/sudoers.d/vro-plugin-user':
    ensure  => file,
    mode    => '0440',
    owner   => 'root',
    group   => 'root',
    content => epp('vra_puppet_plugin_prep/vro_sudoer_file.epp'),
  }

  sshd_config { 'PasswordAuthentication':
    ensure => present,
    value  => 'yes',
  }

  sshd_config { 'ChallengeResponseAuthentication':
    ensure => present,
    value  => 'no',
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

