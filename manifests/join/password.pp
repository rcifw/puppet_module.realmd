# == Class realmd::join::password
#
# This class is called from realmd for
# joining AD using a username and password.
#
class realmd::join::password {

  $_domain             = $::realmd::domain
  $_domain_ipaddr      = $::realmd::domain_ipaddr
  $_user               = $::realmd::domain_join_user
  $_password           = $::realmd::domain_join_password
  $_ou                 = $::realmd::ou
  $_extra_join_options = $::realmd::extra_join_options

  if $::realmd::computer_name != undef {
    $_computer_name = $::realmd::computer_name
  } else {
    fail('Computer name is not set. Please set `realmd::computer_name`')
  }

  if $facts['os']['name'] == 'Ubuntu' {
      $_computer_name_arg  = $facts['os']['distro']['codename'] ? {
      'xenial'  => '',
      'bionic'  => '',
      'focal'   => '',
      'jammy'   => '',
      default => ["--computer-name=${_computer_name}"],
    }
  } else {
      $_computer_name_arg = ["--computer-name=${_computer_name}"]
  }

  # If an IP address is provided, use it as the first argument
  # instead of the domain. This is useful when the DNS is not working.
  $_first_arg = $_domain_ipaddr ? {
    undef   => $_domain,
    default => $_domain_ipaddr,
  }
  if $_ou != undef {
    $_realm_args = [$_first_arg, '--unattended', "--computer-ou='${_ou}'", "--user=${_user}"]
  } else {
    $_realm_args = [$_first_arg, '--unattended', "--user=${_user}"]
  }

  $_args = strip(join(concat($_realm_args, $_computer_name_arg, $_extra_join_options), ' '))

  if $facts['os']['release']['major'] == '6' and $facts['os']['family'] == 'RedHat' {
    $_command = "echo -n ${_password} | adcli join --login-user=${_user} --domain=${_domain} --domain-ou '${_ou}' --computer-name ${_computer_name} --stdin-password" #lint:ignore:140chars

  } else {
    file { '/usr/libexec':
      ensure  => 'directory',
    }

    file { '/usr/libexec/realm_join_with_password':
      ensure  => file,
      owner   => '0',
      group   => '0',
      mode    => '0755',
      content => template('realmd/realm_join_with_password.erb'),
      notify  => Exec['realm_join_with_password'],
    }
    $_command = "/usr/libexec/realm_join_with_password realm join ${_args}"
  }

  exec { 'realm_join_with_password':
    environment => ["AD_JOIN_PASSWORD=${_password}"],
    path        => '/usr/bin:/usr/sbin:/bin',
    command     => $_command,
    unless      => "klist -k /etc/krb5.keytab | grep -i '${_computer_name}@${_domain}'",
  }
}
