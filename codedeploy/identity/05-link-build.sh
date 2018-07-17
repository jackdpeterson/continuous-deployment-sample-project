#!/bin/bash
exec 1> >(logger -s -t $(basename $0)) 2>&1

DOMAIN_NAME='example.com'
SERVICE_NAME='identity'

###
#  Read in the requested HTTP_HOST based on the environment variable
###
if [ "${DEPLOYMENT_GROUP_NAME}" != "production" ]; then
    http_host_destination="${SERVICE_NAME}-${DEPLOYMENT_GROUP_NAME}.${DOMAIN_NAME}"
else
    http_host_destination="${SERVICE_NAME}.${DOMAIN_NAME}"
fi;


if [ "" = "${http_host_destination}" ]; then
	echo "Uh oh - there was a problem getting the http_host destination information. Check Syslogs!" 1>&2
	exit 2;
fi

if [ ! -d "/var/www/domains/" ]; then
	mkdir -p /var/www/domains
fi

## Unlink or Delete directory and re-link
if [ -L "/var/www/domains/${http_host_destination}" ]; then
		rm "/var/www/domains/${http_host_destination}"
	else
	if [ -d "/var/www/domains/${http_host_destination}" ]; then
		rmdir "/var/www/domains/${http_host_destination}"
	fi
fi

ln -s "/var/www/builds/${APPLICATION_NAME}/${DEPLOYMENT_GROUP_NAME}-${DEPLOYMENT_ID}" "/var/www/domains/${http_host_destination}"

if [ ! -L "/var/www/domains/${http_host_destination}" ]; then
	echo "Failed at linking!"  1>&2
	exit 2;
fi

exit 0;