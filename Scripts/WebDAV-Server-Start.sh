#!/bin/sh

# exec > ~/prebuild.log 2>&1

testfolder=${SRCROOT}/MobileOrgTests/Resources/WebDavTests
if $(docker inspect phylor/webdav-ssl >/dev/null 2>&1); then
echo "Image does exist";
else
echo "Image does not exist"
docker pull phylor/webdav-ssl
fi

docker run -d --name mobileOrg-webDAV -v $testfolder/htpasswd:/htpasswd -v $testfolder/certs:/certs -v $testfolder/content:/var/www -h mobileOrgWebDav.schnuddelhuddel.de -p 32773:443 phylor/webdav-ssl
