#!/bin/bash
exec 1> >(logger -s -t $(basename $0)) 2>&1
echo "start validating service"

DOMAIN_NAME='example.com'
SERVICE_NAME='identity'

if [ "${DEPLOYMENT_GROUP_NAME}" != "production" ]; then
    http_host_destination="${SERVICE_NAME}-${DEPLOYMENT_GROUP_NAME}.${DOMAIN_NAME}"
else
    http_host_destination="${SERVICE_NAME}.${DOMAIN_NAME}"
fi;


if [ ! -L "/var/www/domains/${http_host_destination}" ]; then
	echo "NOT LINKED PROPERLY!!!" 1>&2
	exit 2;
fi

echo "Restarting PHP FPM!"
## Restart PHP-FPM for 7.1 if it is installed
hash php7.2 2> /dev/null || sudo service php7.1-fpm restart

## Restart PHP-FPM for 7.2 if it is installed
hash php7.1 2> /dev/null || sudo service php7.2-fpm restart

echo "Done validating service"
