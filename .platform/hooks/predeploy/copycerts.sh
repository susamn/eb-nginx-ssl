#!/bin/bash

exec 1>/var/log/eb-sslcopy.log 2>&1
cd /data
set -x
set -e

s3Bucket=$(/opt/elasticbeanstalk/bin/get-config \
            environment -k PRIVATE_BUCKET)
certPath=$(/opt/elasticbeanstalk/bin/get-config \
            environment -k CERT_PATH)
region=$(TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` \
        && curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/dynamic/instance-identity/document | \
          python -c 'import sys, json; print json.load(sys.stdin)["region"]')

aws --region $region s3 cp \
  --recursive \
  --exclude "*" \
  --include "server.key" \
  --include "server.crt" \
  s3://${s3Bucket}/${certPath}/ \
  /dev/shm/

for object in crt key; do
   /usr/bin/test -f \
      /dev/shm/server.${object}

  case $object in
     "crt")
         cp -f /dev/shm/server.$object \
               /etc/pki/tls/certs/server.$object
         rm /dev/shm/server.$object
         ;;
     "key")
         cp -f /dev/shm/server.$object \
               /etc/pki/tls/private/server.$object
         rm /dev/shm/server.$object
         chmod 400 /etc/pki/tls/private/server.$object
         ;;
  esac

done
rm -f /dev/shm/server.key \
    /dev/shm/server.crt