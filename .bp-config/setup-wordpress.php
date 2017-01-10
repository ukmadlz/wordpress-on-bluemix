<?php
// Build the DB CA Cert
echo "  Build CA Cert\n";
$vcap_services = json_decode(getenv('VCAP_SERVICES'), true);
$composeformysql = $vcap_services['compose-for-mysql'][0]['credentials'];
$cacert = base64_decode($composeformysql['ca_certificate_base64']);
file_put_contents(dirname(__FILE__) . '/../content/dbcert.pem', $cacert);
// Build the wp-config.php
echo "  Setup wp-config.php\n";
copy(dirname(__FILE__) . '/wp-config.php', dirname(__FILE__) . '/../content/wp-config.php');
// Move the secure DB handler
echo "  Setup secure db handler\n";
copy(dirname(__FILE__) . '/../wp-content/plugins/secure-db-connection/lib/db.php', dirname(__FILE__) . '/../content/wp-content/db.php');
