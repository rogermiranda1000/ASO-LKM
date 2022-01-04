#!/bin/bash
if [ "$REQUEST_METHOD" != "POST" ]; then
	echo "Status: 400"
	echo "content-type: text/plain"
	echo
	echo "POST request expected"
	
	exit 1
fi

# extract post data
declare -A post_info
read post_data
read tmp1 tmp2 <<< `echo "$post_data" | cut -d "&" -f 1 | awk -F= '{ print $1 " " $2 }'`
post_info["$tmp1"]="$tmp2"
read tmp1 tmp2 <<< `echo "$post_data" | cut -d "&" -f 2 | awk -F= '{ print $1 " " $2 }'`
post_info["$tmp1"]="$tmp2"

login_file="login.log"
echo "${post_info[password]}" | su -l "${post_info[username]}" 2>"$login_file"
if [ `grep -c "does not exist" "$login_file"` -gt 0 ]; then
	echo "Status: 401"
	echo "content-type: text/plain"
	echo
	echo "Invalid user"
elif [ `grep -c "Authentication failure" "$login_file"` -gt 0 ]; then
	echo "Status: 401"
	echo "content-type: text/plain"
	echo
	echo "Invalid password"
else
	echo "content-type: text/plain"
	echo
	echo "{\"token\": \"t\"}"
fi
rm "$login_file"
