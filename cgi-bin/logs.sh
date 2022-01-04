#!/bin/bash

# Obtè el token d'usuari
# @param '<username> <password>'
function getToken() {
	echo -n "$1" | md5sum | awk '{ printf("%s", $1) }'
}

function getUser() {
	token=`echo "$HTTP_COOKIE" | grep -P -o '(?<=token=)[^;]+'` # token de login
	cat "logins.txt" |
		while read line; do
			if [ `getToken "$line"` = "$token" ]; then
				echo "$line" | awk '{ print $1 }'
				
				return 0
			fi
		done
	return 1
}

user=`getUser`
if [ -z "$user" ]; then
	echo "Status: 401"
	echo "content-type: text/plain"
	echo
	echo "{\"err\": \"The current user don't have access to the logs.\"}"
else
	echo "content-type: text/plain"
	echo
	# last 10 logins
	msg=""
	while read -r line; do
		msg=`echo -n "$msg"; echo "$line" | awk '{ print "{\"user\":\"" $7 "\",\"date\":\"" $1 " " $2 " - " $3 "\"}," }'`
	done <<< `sudo cat /var/log/website_manager.log | grep 'logged in' | tail`
	echo -n "{\"last\": [${msg::-1}], \"logs\": \""
	sudo cat /var/log/website_manager.log | sed -z -r 's/"/\\"/g' | sed -z -r 's/\n/\\n/g' # elimina '\n' i converteix caracters especials en HTML
	echo "\"}"
fi