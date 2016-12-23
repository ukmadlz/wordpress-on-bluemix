#!bin/bash

# Copyright 2016 IBM Corp. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the “License”);
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an “AS IS” BASIS,
#
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

echo 'Upload WordPress to IBM Bluemix';

# App name
read -p "App Name: " WORDPRESSNAME;

# Presets
WORDPRESS="https://wordpress.org/latest.zip";
MYSQLSERVICE="WordpressDatabase";

# Make sure CF is installed
command -v cf >/dev/null 2>&1 || { echo >&2 "I require cf but it's not installed.  Aborting."; exit 1; }

# Download the source
command -v curl >/dev/null 2>&1 || { echo >&2 "I require curl but it's not installed.  Aborting."; exit 1; }
curl -X GET ${WORDPRESS} > wordpress.zip;

# Create DB Instance
cf create-service compose-for-mysql Standard $MYSQLSERVICE;

# Generate KEYS
AUTHKEY="1";
SECUREAUTHKEY="2";
LOGGEDINKEY="3";
NONCEKEY="4";
AUTHSALT="5";
SECUREAUTHSALT="6";
LOGGEDINSALT="7";
NONCESALT="8";

# Unzip the
unzip wordpress.zip;

# Setup the working directory
mkdir wordpress/.bp-config;
echo "{
    \"WEBDIR\": \"wordpress\"
}" > wordpress/.bp-config/options.json;

# Write the wp-config.php
echo "<?php
if(isset(\$_ENV['VCAP_SERVICES'])) {
    \$vcap_services = json_decode(\$_ENV['VCAP_SERVICES'], true);
    \$composeformysql = \$vcap_services['compose-for-mysql'][0]['credentials'];
    \$mysqlconfig = parse_url(\$composeformysql['uri']);
} else {
    echo 'No Config'; die();
}
define('DB_NAME', 'compose');
define('DB_USER', \$mysqlconfig['user']);
define('DB_PASSWORD', \$mysqlconfig['pass']);
define('DB_HOST', \$mysqlconfig['host'].':'.\$mysqlconfig['port'].\$mysqlconfig['path']);
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
define('AUTH_KEY',         \$_ENV['AUTH_KEY']);
define('SECURE_AUTH_KEY',  \$_ENV['SECURE_AUTH_KEY']);
define('LOGGED_IN_KEY',    \$_ENV['LOGGED_IN_KEY']);
define('NONCE_KEY',        \$_ENV['NONCE_KEY']);
define('AUTH_SALT',        \$_ENV['AUTH_SALT']);
define('SECURE_AUTH_SALT', \$_ENV['SECURE_AUTH_SALT']);
define('LOGGED_IN_SALT',   \$_ENV['LOGGED_IN_SALT']);
define('NONCE_SALT',       \$_ENV['NONCE_SALT']);
// Hack till MySQL over SSL is implemented
define('MYSQL_CLIENT_FLAGS', MYSQL_CLIENT_SSL);//This activates SSL mode
define('MYSQL_SSL_CA', base64_decode(\$composeformysql['ca_certificate_base64']));
\$table_prefix  = 'wp_';
define('WP_DEBUG', false);
if ( !defined('ABSPATH') )
	define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
" > wordpress/wp-config.php;

# Add the SSL to wp-dp.php
sed -iold '1536i\'$'\n''if ( \$client_flags & MYSQL_CLIENT_SSL ) {\$pack = array( \$this->dbh );\$call_set = false;foreach( array( 'MYSQL_SSL_KEY', 'MYSQL_SSL_CERT', 'MYSQL_SSL_CA','MYSQL_SSL_CAPATH', 'MYSQL_SSL_CIPHER' ) as \$opt_key ) {\$pack[] = ( defined( \$opt_key ) ) ? constant( \$opt_key ) : null;\$call_set |= defined( \$opt_key );}if ( \$call_set ) {call_user_func_array( 'mysqli_ssl_set', \$pack );}}'$'\n' wordpress/wp-includes/wp-db.php

# Push app to Bluemix
cf push $WORDPRESSNAME

# Bind DB to the app
cf bind-service $WORDPRESSNAME $MYSQLSERVICE;

# Assign KEYs to the application
cf set-env $WORDPRESSNAME AUTH_KEY $AUTHKEY;
cf set-env $WORDPRESSNAME SECURE_AUTH_KEY $SECUREAUTHKEY;
cf set-env $WORDPRESSNAME LOGGED_IN_KEY $LOGGEDINKEY;
cf set-env $WORDPRESSNAME NONCE_KEY $NONCEKEY;
cf set-env $WORDPRESSNAME AUTH_SALT $AUTHSALT;
cf set-env $WORDPRESSNAME SECURE_AUTH_SALT $SECUREAUTHSALT;
cf set-env $WORDPRESSNAME LOGGED_IN_SALT $LOGGEDINSALT;
cf set-env $WORDPRESSNAME NONCE_SALT $NONCESALT;

# Restart for good measure
cf restage $WORDPRESSNAME;

# Clean-up
rm -Rf wordpress
rm wordpress.zip
