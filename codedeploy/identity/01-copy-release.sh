#!/bin/bash
exec 1> >(logger -s -t $(basename $0)) 2>&1
S3_CONFIGURATION_BUCKET='secrets.jpeterson-udemy-example.com';

## Create builds path if it does not exist
if [ ! -d "/var/www/builds" ]; then
	sudo mkdir -p /var/www/builds && sudo chown ubuntu:ubuntu /var/www/builds && sudo chmod 775 /var/www/builds
fi


## move code from the tmp folder to the build folder

if [ -d "/var/www/builds/${APPLICATION_NAME}/${DEPLOYMENT_GROUP_NAME}-${DEPLOYMENT_ID}" ]; then
	rm -rf /var/www/builds/${APPLICATION_NAME}/${DEPLOYMENT_GROUP_NAME}-${DEPLOYMENT_ID}
fi

sudo chown -R ubuntu:ubuntu /var/current-deployment

sudo mkdir -p /var/www/builds/${APPLICATION_NAME}


sudo mv /var/current-deployment /var/www/builds/${APPLICATION_NAME}/${DEPLOYMENT_GROUP_NAME}-${DEPLOYMENT_ID}

sudo mkdir -p /var/www/builds/${APPLICATION_NAME}/${DEPLOYMENT_GROUP_NAME}-${DEPLOYMENT_ID}/log
sudo chmod 0777 /var/www/builds/${APPLICATION_NAME}/${DEPLOYMENT_GROUP_NAME}-${DEPLOYMENT_ID}/log
sudo chown www-data:www-data /var/www/builds/${APPLICATION_NAME}/${DEPLOYMENT_GROUP_NAME}-${DEPLOYMENT_ID}/log


cd /var/www/builds/${APPLICATION_NAME}/${DEPLOYMENT_GROUP_NAME}-${DEPLOYMENT_ID}

touch /var/www/builds/${APPLICATION_NAME}/${DEPLOYMENT_GROUP_NAME}-${DEPLOYMENT_ID}/log.log
chmod 0666 /var/www/builds/${APPLICATION_NAME}/${DEPLOYMENT_GROUP_NAME}-${DEPLOYMENT_ID}/log.log

if [ -f "public/.htaccess" ]; then
sudo rm public/.htaccess
fi

cat << EOF > public/.htaccess
SetEnv APPLICATION_ENV ${DEPLOYMENT_GROUP_NAME}
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^ index.php [QSA,L]
Header set Access-Control-Allow-Origin "*"
Header set Access-Control-Allow-Methods: "GET,POST,OPTIONS,DELETE,PUT"
EOF

if [ -d "/var/current-deployment" ]; then
    sudo rm -rf /var/current-deployment
fi

## copy env.php file
if [ -f "env.php" ]; then
    rm -f env.php
fi

aws s3 cp s3://${S3_CONFIGURATION_BUCKET}/${APPLICATION_NAME}/${DEPLOYMENT_GROUP_NAME}/env.php env.php

if [ ! -f "env.php" ]; then
    echo "NO ENV FILE LOADED";
    exit 2;
fi

mkdir -p /var/www/builds/${APPLICATION_NAME}/${DEPLOYMENT_GROUP_NAME}-${DEPLOYMENT_ID}/cache/proxies
php vendor/doctrine/orm/bin/doctrine orm:generate-proxies

sudo chmod 0777 /var/www/builds/${APPLICATION_NAME}/${DEPLOYMENT_GROUP_NAME}-${DEPLOYMENT_ID}/cache/proxies
sudo chmod 0777 /var/www/builds/${APPLICATION_NAME}/${DEPLOYMENT_GROUP_NAME}-${DEPLOYMENT_ID}/cache

sudo chown www-data:ubuntu /var/www/builds/${APPLICATION_NAME}/${DEPLOYMENT_GROUP_NAME}-${DEPLOYMENT_ID}/sso.pub
sudo chmod 0600 /var/www/builds/${APPLICATION_NAME}/${DEPLOYMENT_GROUP_NAME}-${DEPLOYMENT_ID}/sso.pub


### AUTOCLEAN OLD DEPLOYMENTS -- BE WARNED, no two applications shall sit on the same server! ###

dir_obj_count=`ls /var/www/builds/${APPLICATION_NAME}/${DEPLOYMENT_GROUP_NAME}-${DEPLOYMENT_ID} | wc -l`

if [ "${dir_obj_count}" = "0" ]; then
	echo "Size of destination build directory is <= 1." 1>&2
	exit 2;
fi
for i in `ls /var/www/builds/${APPLICATION_NAME}/ -lt | awk '{print $9}' | grep ${DEPLOYMENT_GROUP_NAME} | tail -n +7`
do
    sudo rm -rf /var/www/builds/${APPLICATION_NAME}/${i}
done

