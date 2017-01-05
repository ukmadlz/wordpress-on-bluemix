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
SSLPLUGIN="https://downloads.wordpress.org/plugin/secure-db-connection.1.1.2.zip";
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

# Unzip wordpress
unzip wordpress.zip;

# Download the secure db connection plugin
curl -X GET ${SSLPLUGIN} > secure-db-connection.zip;

# Unzip the secure db connection plugin
unzip secure-db-connection.zip;

# Move the plugin into place
cp -R secure-db-connection ./wordpress/wp-content/plugins/

# Move the DB file into wp-content
cp secure-db-connection/lib/db.php ./wordpress/wp-content/db.php

# Setup the working directory
mkdir wordpress/.bp-config;
echo "{
    \"WEBDIR\": \"/\"
}" > wordpress/.bp-config/options.json;

# Write the wp-config.php
echo "<?php
if(getenv('VCAP_SERVICES')) {
    \$vcap_services = json_decode(getenv('VCAP_SERVICES'), true);
    \$composeformysql = \$vcap_services['compose-for-mysql'][0]['credentials'];
    \$mysqlconfig = parse_url(\$composeformysql['uri']);
    \$cacert = base64_decode(\$composeformysql['ca_certificate_base64']);
    file_put_contents(dirname(__FILE__) . '/dbcert.pem', \$cacert);
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
define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);
define('MYSQL_SSL_CA', dirname(__FILE__) . '/dbcert.pem');
\$table_prefix  = 'wp_';
define('WP_DEBUG', false);
if ( !defined('ABSPATH') )
	define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
" > wordpress/wp-config.php;

# Setup Composer
echo "{
    \"require\": {
        \"php\": \"5.5.*\"
    }
}" > wordpress/composer.json
echo "{
    \"_readme\": [
        \"This file locks the dependencies of your project to a known state\",
        \"Read more about it at https://getcomposer.org/doc/01-basic-usage.md#composer-lock-the-lock-file\",
        \"This file is @generated automatically\"
    ],
    \"content-hash\": \"d779e9c1c97874f3c1ac443bb53cefa9\",
    \"packages\": [],
    \"packages-dev\": [],
    \"aliases\": [],
    \"minimum-stability\": \"stable\",
    \"stability-flags\": [],
    \"prefer-stable\": false,
    \"prefer-lowest\": false,
    \"platform\": {
        \"php\": \"5.5.*\"
    },
    \"platform-dev\": []
}" > wordpress/composer.lock
echo "vendor" > wordpress/.cfignore

# Push app to Bluemix
cd wordpress
cf push $WORDPRESSNAME -b https://github.com/heroku/heroku-buildpack-php.git
cd ../

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
read -p "Clean up zip/directories? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  # Clean-up directories
  rm -Rf wordpress
  rm -Rf secure-db-connection
  # Clean-up zips
  rm wordpress.zip
  rm secure-db-connection.zip
fi
