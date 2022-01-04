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
			logger -p local7.info `echo "$line" | awk  '{ print "User " $1 " logged out." }'`
			
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