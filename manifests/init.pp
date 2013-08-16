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
class osqa {

  include apache
  include apache::mod::wsgi

  vcsrepo { '/var/www/osqa':
    ensure   => present,
    provider => svn,
    source   => 'http://svn.osqa.net/svnroot/osqa/trunk/',
    revision => '1285',
  }

}
