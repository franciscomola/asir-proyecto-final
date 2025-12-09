<?php
$CONFIG = array (
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
  'overwritehost' => 'asir.local',
  'overwriteprotocol' => 'https',
  'upgrade.disable-web' => true,
  'passwordsalt' => 'sxfq8RI+K3PJTC9fT0364TUXDMYs1e',
  'secret' => 'QA4jx7Um1YdKXZcpUu1n6vBdtkJLk6T2oXXE+K0SpBQJPBTX',
  'trusted_domains' => 
  array (
    0 => 'localhost',
    1 => 'lab.local',
    2 => 'asir.local',
    3 => 'localhost',
    4 => '127.0.0.1',
  ),
  'datadirectory' => '/var/www/html/data',
  'dbtype' => 'mysql',
  'version' => '28.0.14.1',
  'overwrite.cli.url' => 'https://localhost',
  'dbname' => 'nextcloud',
  'dbhost' => 'db',
  'dbport' => '',
  'dbtableprefix' => 'oc_',
  'mysql.utf8mb4' => true,
  'dbuser' => 'nextcloud',
  'dbpassword' => 'nextcloudpass',
  'installed' => true,
  'instanceid' => 'oc65cs5vn87d',
  'ldapProviderFactory' => 'OCA\\User_LDAP\\LDAPProviderFactory',
);
