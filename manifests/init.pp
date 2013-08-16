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
  $wsgi_group  = 'OSQA',
) {

  include apache
  include apache::mod::wsgi

  #this is your wsgi script described in the prev section
  #WSGIScriptAlias / /home/osqa/osqa-server/osqa.wsgi
  user { $username:
    ensure     => present,
    managehome => true,
  }

  # FIXME: 2013/08/16 apache module does not support wsgi yet
  file { '/etc/apache2/sites-available/wsgi.conf':
    ensure  => file,
    content => 'WSGISocketPrefix ${APACHE_RUN_DIR}',
    notify  => Service['apache2'],
  }

  # FIXME: 2013/08/16 apache module does not support wsgi yet
  apache::vhost { 'osqa-vhost':
    port            => 80,
    docroot         => "$install_dir/osqa-server",
    custom_fragment => "  WSGIProcessGroup $wsgi_group \n  WSGIProcessGroup $wsgi_group\n  WSGIScriptAlias / $install_dir/osqa-server/osqa.wsgi",
    directories => [
      { path => "$install_dir/osqa-server/forum/upfiles", order => 'deny,allow', allow => 'from all' },
      { path => "$install_dir/osqa-server/forum/skins", order => 'allow,deny', allow => 'from all' }
    ],
    aliases => [
      { alias => '/m/', path => "$install_dir/osqa-server/forum/skins" },
      { alias => '/upfiles/', path => "$install_dir/osqa-server/forum/upfiles" }
    ],
    require => Vcsrepo[$install_dir],
  }

  vcsrepo { $install_dir:
    ensure   => present,
    provider => svn,
    source   => 'http://svn.osqa.net/svnroot/osqa/trunk/',
    revision => '1285',
    require  => User['osqa'],
  }

  file { "${install_dir}/wsgi":
    content => template('osqa/osqa.wsgi.erb'),
    require => User['osqa'],
  }

  class { 'mysql::server':
    config_hash => { 'root_password' => hiera('mysql_root_password', 'changme!') },
  }

  mysql::db { 'osqa':
    user     => 'osqa',
    password => hiera('osqa_db_password', 'changme!'),
    grant    => ['all'],
  }

  Class['mysql::server'] -> Mysql::Db['osqa']

}
