# == Class: osqa
#
# Installs and configures the osqa webapp
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if it
#   has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should not be used in preference to class parameters  as of
#   Puppet 2.6.)
#
# === Examples
#
#  class { osqa: }
#
# === Authors
#
# Spencer Krum <krum.spencer@gmail.com>
# William Van Hevelingen <wvan13@gmail.com>
#
# === Copyright
#
# Copyright 2013 Your name here, unless otherwise noted.
#
class osqa (
  $install_dir = '/home/osqa',
  $username    = 'osqa',
  $db_name     = 'osqa',
  $timezone    = 'Americas/Los_Angeles',
  $app_url     = 'http://puppet-article-3',
  $db_username = $username,
  $db_password = hiera('osqa_db_password', 'changme!'),
) {

  class { 'apache':
    default_vhost => false,
  }
  include apache::mod::wsgi

  user { $username:
    ensure     => present,
    managehome => true,
  }

  # FIXME: 2013/08/16 apache module does not support wsgi yet
  file { '/etc/apache2/sites-enabled/wsgi.conf':
    ensure  => file,
    content => "WSGISocketPrefix ${APACHE_RUN_DIR}WSGI\nWSGIPythonHome ${install_dir}/virtenv-osqa",
    notify  => Service['apache2'],
  }

  # FIXME: 2013/08/16 apache module does not support wsgi yet
  apache::vhost { 'osqa-vhost':
    port            => 80,
    docroot         => "$install_dir/osqa-server",
    custom_fragment => "  WSGIDaemonProcess OSQA \n  WSGIProcessGroup OSQA\n  WSGIScriptAlias / $install_dir/osqa-server/osqa.wsgi\n ",
    directories => [
      { path => "$install_dir/osqa-server/forum/upfiles", order => 'deny,allow', allow => 'from all' },
      { path => "$install_dir/osqa-server/forum/skins", order => 'allow,deny', allow => 'from all' }
    ],
    aliases => [
      { alias => '/m/', path => "$install_dir/osqa-server/forum/skins" },
      { alias => '/upfiles/', path => "$install_dir/osqa-server/forum/upfiles" }
    ],
    require => Vcsrepo["${install_dir}/osqa-server"],
  }

  vcsrepo { "${install_dir}/osqa-server":
    ensure   => present,
    provider => svn,
    source   => 'http://svn.osqa.net/svnroot/osqa/trunk/',
    revision => '1285',
    user     => $username,
    owner    => $group,
    require  => User['osqa'],
  }

  file { "${install_dir}/osqa-server/osqa.wsgi":
    content => template('osqa/osqa.wsgi.erb'),
    require => User['osqa'],
  }

  class { 'mysql::server':
    config_hash => { 'root_password' => hiera('mysql_root_password', 'changme!') },
  }

  include mysql::bindings::python

  mysql::db { $db_name:
    user     => $db_username,
    password => $db_password,
    grant    => ['all'],
  }

  file { "$install_dir/settings_local.py":
    owner   => $username,
    content => template('osqa/settings_local.py.erb'),
    require => Vcsrepo["${install_dir}/osqa-server"]
  }

  file { "$install_dir/requirements.txt":
    content => template('osqa/requirements.txt'),
    require => Vcsrepo["${install_dir}/osqa-server"]
  }

  class { 'python':
    version    => 'system',
    dev        => true,
    virtualenv => true,
  }

  python::virtualenv { "${install_dir}/virtenv-osqa":
    ensure       => present,
    version      => 'system',
    systempkgs   => false,
    distribute   => false,
    requirements => "${install_dir}/requirements.txt",
    owner        => $username,
    require      => [Vcsrepo["${install_dir}/osqa-server"], Class['python'], File["${install_dir}/requirements.txt"]],
  }

  exec { 'syncdb':
    cwd         => "${install_dir}/osqa-server",
    provider    => shell,
    user        => $username,
    command     => "source ../virtenv-osqa/bin/activate && ${install_dir}/virtenv-osqa/bin/python manage.py syncdb --all",
    refreshonly => true,
    notify      => Exec['migrate-forum'],
  }

  exec { 'migrate-forum':
    cwd         => "${install_dir}/osqa-server",
    provider    => shell,
    user        => $username,
    command     => "source ../virtenv-osqa/bin/activate && ${install_dir}/virtenv-osqa/bin/python manage.py migrate forum --fake",
    refreshonly => true,
  }

  Class['python'] -> Python::Virtualenv <| |>
  -> Python::Pip <| |> -> Class['mysql::server']
  -> Mysql::Db[$db_name]

}
