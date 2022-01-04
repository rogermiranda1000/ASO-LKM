#!/bin/bash

# Obtè el token d'usuari
# @param username
# @param password
function getToken() {
	echo -n "$1 $2" | md5sum | awk '{ printf("%s", $1) }'
}

if [ "$REQUEST_METHOD" != "POST" ]; then
	echo "Status: 400"
	echo "content-type: text/plain"
	echo
	echo "{\"err\": \"POST request expected\"}"
	
	exit 1
fi

# extract post data
declare -A post_info
read post_data
read tmp1 tmp2 <<< `echo "$post_data" | cut -d "&" -f 1 | awk -F= '{ print $1 " " $2 }'`
post_info["$tmp1"]="$tmp2"
read tmp1 tmp2 <<< `echo "$post_data" | cut -d "&" -f 2 | awk -F= '{ print $1 " " $2 }'`
post_info["$tmp1"]="$tmp2"

login_file=`mktemp`
echo "${post_info[password]}" | su -l "${post_info[username]}" 2>"$login_file"
if [ `grep -c "does not exist" "$login_file"` -gt 0 ]; then
	echo "Status: 401"
	echo "content-type: text/plain"
	echo
	echo "{\"err\": \"Invalid user\"}"
elif [ `grep -c "Authentication failure" "$login_file"` -gt 0 ]; then
	echo "Status: 401"
	echo "content-type: text/plain"
	echo
	echo "{\"err\": \"Invalid password\"}"
else
	echo "content-type: text/plain"
	echo
	echo "${post_info[username]} ${post_info[password]}" >> logins.txt # afegir al fitxer de logins
	echo -n "{\"token\": \""
	getToken "${post_info[username]}" "${post_info[password]}"
	echo -n "\"}"
fi
