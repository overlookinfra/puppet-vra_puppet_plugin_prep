# vra_puppet_plugin_prep
#
# A description of what this class does
#
# @summary Prepares a PE master for vRA Puppet Plugin integration.
#
# @example
#   include vra_puppet_plugin_prep
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

  $ruby_mk_vro_plugin_user = epp('vra_puppet_plugin_prep/create_user_role.rb.epp', {
    'username'    => $vro_plugin_user,
    'password'    => $vro_password,
    'rolename'    => 'VRO Plugin User',
    'touchfile'   => '/opt/puppetlabs/puppet/cache/vro_plugin_user_created',
    'permissions' => [
      { 'action'      => 'view_data',
        'instance'    => '*',
        'object_type' => 'nodes',
      },
    ],
  })

  exec { 'create vro user and role':
    command => "/opt/puppetlabs/puppet/bin/ruby -e ${shellquote($ruby_mk_vro_plugin_user)}",
    creates => '/opt/puppetlabs/puppet/cache/vro_plugin_user_created',
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
      content => template('vra_puppet_plugin_prep/autosign.rb.erb'),
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

