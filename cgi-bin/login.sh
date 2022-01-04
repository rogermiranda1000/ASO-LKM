#!/bin/bash
if [ "$REQUEST_METHOD" != "POST" ]; then
	echo "Status: 400"
	echo "content-type: text/plain"
	echo
	echo "POST request expected"
	
	exit 1
fi

echo "content-type: text/html; charset=utf-8"
echo

# extract post data
declare -A post_info
read post_data
read tmp1 tmp2 <<< `echo "$post_data" | cut -d "&" -f 1 | awk -F= '{ print $1 " " $2 }'`
post_info["$tmp1"]="$tmp2"
read tmp1 tmp2 <<< `echo "$post_data" | cut -d "&" -f 2 | awk -F= '{ print $1 " " $2 }'`
post_info["$tmp1"]="$tmp2"

echo "${post_info[password]}" | su -l "${post_info[username]}" 2>login.log
grep -c "Authentication failure" login.log
grep -c "does not exist" login.log