<?php
if(getenv('VCAP_SERVICES')) {
    $vcap_services = json_decode(getenv('VCAP_SERVICES'), true);
    $composeformysql = $vcap_services['compose-for-mysql'][0]['credentials'];
    $mysqlconfig = parse_url($composeformysql['uri']);
} else {
    echo 'No Config'; die();
}
define('DB_NAME', 'compose');
define('DB_USER', $mysqlconfig['user']);
define('DB_PASSWORD', $mysqlconfig['pass']);
define('DB_HOST', $mysqlconfig['host'].':'.$mysqlconfig['port'].$mysqlconfig['path']);
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
define('AUTH_KEY',         getenv('AUTH_KEY'));
define('SECURE_AUTH_KEY',  getenv('SECURE_AUTH_KEY'));
define('LOGGED_IN_KEY',    getenv('LOGGED_IN_KEY'));
define('NONCE_KEY',        getenv('NONCE_KEY'));
define('AUTH_SALT',        getenv('AUTH_SALT'));
define('SECURE_AUTH_SALT', getenv('SECURE_AUTH_SALT'));
define('LOGGED_IN_SALT',   getenv('LOGGED_IN_SALT'));
define('NONCE_SALT',       getenv('NONCE_SALT'));
// Hack till MySQL over SSL is implemented
define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);
define('MYSQL_SSL_CA', dirname(__FILE__) . '/dbcert.pem');
// Disable FS Modification
define('DISALLOW_FILE_MODS', true);
$table_prefix  = 'wp_';
define('WP_DEBUG', getenv('WP_DEBUG') || false);
if ( !defined('ABSPATH') )
	define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
