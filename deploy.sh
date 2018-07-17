#!/usr/bin/env bash
set -e


SOURCE=$(dirname "$0")
if [ "${SOURCE}" = '.' ]; then
SOURCE=$(pwd)
fi

rm -rf ${SOURCE}/deploy
mkdir -p ${SOURCE}/deploy

echo ${SOURCE}

RANDOM_BYTES=$(php -r 'echo bin2hex(random_bytes(8));')

APPLICATION="com.example.identity"
NOW=$(date +"%Y-%m-%d_%H:%M:%S")

echo "Date: ${NOW}"

AWS_PROFILE="deploy"
AWS_BUCKET="com.example.codedeploy"
AWS_REGION="us-east-1"
DEPLOYMENT_GROUP=${1:-beta}

if [ -z "${AWS_PROFILE}" ]; then
    echo "missing AWS profile name"
    exit 2
fi

# copy all the things but vendor and this folder into a subdir



if [ -d "tmp" ]; then
  echo "removing local tmp dir (CLEANING)"
    rm -rf ${SOURCE}/deploy/tmp
fi

echo "Synchronizing root-level folder excluding ... (some directories, symlinks)."
rsync -a --delete --no-links --exclude "vendor/" --exclude "deploy/" --exclude ".git/" --exclude "env.php" ${SOURCE}/ ${SOURCE}/deploy/tmp/


## copy the AWS CodeDeploy configuration in with a unique destination so multiple environments can be supported on a single ASG.
cat <<EOF > ${SOURCE}/deploy/tmp/appspec.yml
version: 0.0
os: linux
files:
  - source: /
    destination: /var/current-deployment-${RANDOM_BYTES}
hooks:
    AfterInstall:
        - location: codedeploy/${APPLICATION}/01-copy-release.sh
          runas: ubuntu
          timeout: 300
        - location: codedeploy/${APPLICATION}/05-link-build.sh
          runas: root
          timeout: 180
    ValidateService:
        - location: codedeploy/${APPLICATION}/07-validate-service.sh
          runas: root
EOF

sed -i "s/\/var\/current-deployment/\/var\/current-deployment-${RANDOM_BYTES}/g" ${SOURCE}/deploy/tmp/codedeploy/${APPLICATION}/01-copy-release.sh
chmod +x ${SOURCE}/deploy/tmp/codedeploy/${APPLICATION}/01-copy-release.sh
sed -i "s/\/var\/current-deployment/\/var\/current-deployment-${RANDOM_BYTES}/g" ${SOURCE}/deploy/tmp/codedeploy/${APPLICATION}/05-link-build.sh
chmod +x ${SOURCE}/deploy/tmp/codedeploy/${APPLICATION}/05-link-build.sh
sed -i "s/\/var\/current-deployment/\/var\/current-deployment-${RANDOM_BYTES}/g" ${SOURCE}/deploy/tmp/codedeploy/${APPLICATION}/07-validate-service.sh
chmod +x ${SOURCE}/deploy/tmp/codedeploy/${APPLICATION}/07-validate-service.sh

mkdir -p ${SOURCE}/deploy/tmp/public

# PHP Application -- install composer dependencies
echo "Starting PHP dependency installation"
cd ${SOURCE}/deploy/tmp && php ${SOURCE}/composer.phar install

if [ ! -f "${SOURCE}/deploy/tmp/vendor/autoload.php" ]; then
    1>&2 echo "missing vendor/autoload.php"
    exit 2
fi


find ${SOURCE}/deploy/tmp -type d -exec chmod 0775 {} \;
find ${SOURCE}/deploy/tmp -type f -exec chmod 0664 {} \;

cd ${SOURCE}/deploy/tmp

# JavaScript dependencies
##npm install

# JavaScript build process
##webpack

## PHP UNIT TESTS
cp env.dist.php env.php
php composer.phar test

# this would be included in the release process
rm env.php

## API Documentation
## generate swagger.json, excluding the vendor path folder
##php vendor/bin/swagger -o swagger.json -e vendor .
## generate the swagger-UI pretty API documentation file
##pretty-swag -i swagger.json -c pretty-swag-config.json -o public/api.html

##rm -rf node_modules

aws deploy push --application-name ${APPLICATION} --s3-location "s3://${AWS_BUCKET}/${APPLICATION}/${NOW}.zip" --source . --profile=${AWS_PROFILE} --region=${AWS_REGION}
CD_CMD="aws deploy create-deployment --application-name ${APPLICATION} --s3-location bucket=${AWS_BUCKET},key=\"${APPLICATION}/${NOW}.zip\",bundleType=zip --deployment-group-name=${DEPLOYMENT_GROUP} --profile=${AWS_PROFILE} --region=${AWS_REGION}"
echo ${CD_CMD}

DEPLOYMENT_ID=$(${CD_CMD} | jq -r ".deploymentId")
echo "Deployment Id: ${DEPLOYMENT_ID}"

DEPLOY_CHECK_COUNT=0
while true; do
    DEPLOY_CHECK_COUNT=$(expr ${DEPLOY_CHECK_COUNT} + 1)

    if [ ${DEPLOY_CHECK_COUNT} -ge 50 ]; then
        1>&2 echo "Been deploying for far too long. failing."
        exit 2
    fi

    echo "sleeping for 10 seconds."
    sleep 10;
    DEPLOY_STATUS=$(aws deploy get-deployment --deployment-id ${DEPLOYMENT_ID} --profile ${AWS_PROFILE} --region=${AWS_REGION} --query "deploymentInfo.status" --output text || true)
    echo "Current deploy status: " . ${DEPLOY_STATUS}
    if [ "$(echo ${DEPLOY_STATUS} | grep -i "succeeded" | wc -l)" == "1" ]; then
        echo "DEPLOY COMPLETE"
        exit 0;
    fi
    if [ "$(echo ${DEPLOY_STATUS} | grep -i "failed" | wc -l)" == "1" ]; then
        1>&2 echo "DEPLOY FAILED"
        exit 2;
    fi
done;