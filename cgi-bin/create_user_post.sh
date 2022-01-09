#!/bin/bash

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

if [ -z "${post_info[username]}" ]; then
	echo "Status: 400"
	echo "content-type: text/plain"
	echo
	echo "{\"err\": \"Username can't be empty!\"}"
	
	exit 1
elif [ -z "${post_info[password]}" ]; then
	echo "Status: 400"
	echo "content-type: text/plain"
	echo
	echo "{\"err\": \"Password can't be empty!\"}"
	
	exit 1
fi

register_file=`mktemp`
sudo useradd -m "${post_info[username]}" 2>"$register_file"
if [ `grep -c "already exists" "$register_file"` -gt 0 ]; then
	echo "Status: 400"
	echo "content-type: text/plain"
	echo
	echo "{\"err\": \"The user specified already exists.\"}"
else
	echo "content-type: text/plain"
	echo
	echo -e -n "${post_info[password]}\n${post_info[password]}\n" | sudo passwd "${post_info[username]}"
	echo "{\"created\": \"${post_info[username]}\"}"
	
	logger -p local7.info "New user created (${post_info[username]})."
fi
