class puppet_stack::puppet::role::aio {
  $ruby_vers             = $::puppet_stack::ruby_vers
  $rvm_prefix            = $::puppet_stack::rvm_prefix
  $puppet_role           = 'aio' # all in one
  $rvm_ruby_root         = "${rvm_prefix}/gems/${ruby_vers}"
  $puppet_cmd            = "${rvm_ruby_root}/bin/puppet"
  $puppet_vardir         = $::puppet_stack::puppet_vardir
  $report_to_foreman     = $::puppet_stack::report_to_foreman
  $use_foreman_as_an_enc = $::puppet_stack::use_foreman_as_an_enc
  $cert_name             = $::puppet_stack::cert_name
  # Graciously borrowed from https://github.com/stephenrjohnson/puppetmodule/blob/master/manifests/passenger.pp
  $cert_clean_cmd        = "${puppet_cmd} cert clean ${cert_name}"
  $cert_gen_cmd          = "${puppet_cmd} certificate --ca-location=local --dns_alt_names=puppet generate ${cert_name}"
  $cert_sign_cmd         = "${puppet_cmd} cert sign --allow-dns-alt-names ${cert_name}"
  $cert_find_cmd         = "${puppet_cmd} certificate --ca-location=local find ${cert_name}"
  
  # Puppet needs permission to create a production environment folder
  file { '/etc/puppet/environments': 
    ensure  => 'directory',
    owner   => 'root',
    group   => 'puppet',
    mode    => '0775',
    require => File['/etc/puppet'],
  }

  file { '/etc/puppet/puppet.conf':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    content => template('puppet_stack/puppet/puppet.conf.erb'),
    notify  => Exec['restart_puppet'],
    require => File['/etc/puppet'],
  }

  file { '/etc/puppet/autosign.conf':
    ensure  => 'file',
    owner   => 'root',
    group   => 'puppet',
    mode    => '0664',
    content => template('puppet_stack/puppet/autosign.conf.erb'),
    require => File['/etc/puppet'],
  }

  file { '/etc/puppet/auth.conf':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    content => template('puppet_stack/puppet/auth.conf.erb'),
    notify  => Exec['restart_puppet'],
    require => File['/etc/puppet'],
  }

  file { '/etc/puppet/manifests':
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File['/etc/puppet'],
  }

  file { '/etc/puppet/modules':
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File['/etc/puppet'],
  }

  file { '/etc/puppet/manifests/site.pp':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    content => template('puppet_stack/puppet/site.pp.erb'),
    require => File['/etc/puppet'],
  }

  if ($use_foreman_as_an_enc == true) {
    file { '/etc/puppet/node.rb':
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0555',
      source  => 'puppet:///modules/puppet_stack/foreman/node.rb',
      require => File['/etc/puppet'],
    }
  }

  if ($report_to_foreman == true) {
    file { "${rvm_ruby_root}/gems/puppet-${::puppetversion}/lib/puppet/reports/foreman.rb":
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0555',
      source  => 'puppet:///modules/puppet_stack/foreman/foreman.rb',
      require => File['/etc/puppet'],
    }
  }
  
  if ($report_to_foreman == true)
  or ($use_foreman_as_an_enc == true) {
    file { '/etc/puppet/foreman.yaml':
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0555',
      content => template('puppet_stack/foreman/foreman.yaml.erb'),
      require => File['/etc/puppet'],
    }
  }

  file { "${puppet_vardir}/reports":
    ensure => 'directory',
    owner  => 'puppet',
    group  => 'puppet',
    mode   => '0750',
  }

  file { "${puppet_vardir}/ssl":
    ensure => 'directory',
    owner  => 'puppet',
    group  => 'puppet',
    mode   => '0771',
    before => File["${puppet_vardir}/ssl/ca"],
  }

  file{ [ "${puppet_vardir}/ssl/ca", "${puppet_vardir}/ssl/ca/requests" ]:
    ensure => 'directory',
    owner  => 'puppet',
    group  => 'puppet',
    mode   => '0770',
    before => Exec['generate_ca_cert'],
  }

  exec { 'generate_ca_cert':
    command   => "${cert_clean_cmd} ; ${cert_gen_cmd} && ${cert_sign_cmd} && ${cert_find_cmd}",
    unless    => "/usr/bin/test -f `${puppet_cmd} config print ssldir`/certs/${cert_name}.pem",
    logoutput => 'on_failure',
    require   => File['/etc/puppet/puppet.conf'],
  }
}
