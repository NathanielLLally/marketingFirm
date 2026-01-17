#!/bin/sh
echo "i must be GROOT!!!"
setsebool -P httpd_can_network_connect on
setsebool -P httpd_can_network_connect_db on
setsebool -P httpd_enable_homedirs 1
setsebool -P httpd_read_user_content 1
setsebool -P httpd_unified 1
