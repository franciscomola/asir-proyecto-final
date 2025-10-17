<?php
$CONFIG = array (
  'htaccess.RewriteBase' => '/',
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'apps_paths' => 
  array (
    0 => 
    array (
      'path' => '/var/www/html/apps',
      'url' => '/apps',
      'writable' => false,
    ),
    1 => 
    array (
      'path' => '/var/www/html/custom_apps',
      'url' => '/custom_apps',
      'writable' => true,
    ),
  ),
  'upgrade.disable-web' => true,
  'passwordsalt' => 'w6DwZGgOili3hk5wKWU9rhAWJiK2Q+',
  'secret' => 'DurpRMSoIDE5op/1rWl+bqutxI6rah6RsfgHn5SCDdEU659Y',
  'trusted_domains' => 
  array (
    0 => 'localhost',
    1 => 'localhost',
  ),
  'datadirectory' => '/var/www/html/data',
  'dbtype' => 'mysql',
  'version' => '28.0.14.1',
  'overwrite.cli.url' => 'http://localhost',
  'dbname' => 'nextcloud',
  'dbhost' => 'db',
  'dbport' => '',
  'dbtableprefix' => 'oc_',
  'mysql.utf8mb4' => true,
  'dbuser' => 'nextcloud',
  'dbpassword' => 'nextcloudpass',
  'installed' => true,
  'instanceid' => 'ocnq5kgmsm4i',
  'ldapProviderFactory' => 'OCA\\User_LDAP\\LDAPProviderFactory',
);
