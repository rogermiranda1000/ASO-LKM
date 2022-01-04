#!/bin/bash

# Obtè el token d'usuari
# @param '<username> <password>'
function getToken() {
	echo -n "$1" | md5sum | awk '{ printf("%s", $1) }'
}

token=`echo "$HTTP_COOKIE" | grep -P -o '(?<=token=)[^;]+'` # token de login
cat "logins.txt" |
	while read line; do
		if [ `getToken "$line"` = "$token" ]; then
			echo "$line" | awk '{ print "User " $1 " logged out."}' >> /var/log/website_manager.log
			
			echo "content-type: text/plain"
			echo
			echo "{\"status\": \"OK\"}"
			
			exit 0
		fi
	done

echo "Status: 400"
echo "content-type: text/plain"
echo
echo "{\"err\": \"Token not found\"}"