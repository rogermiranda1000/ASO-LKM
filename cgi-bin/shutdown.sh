#!/bin/bash

# @param user
function isSudoer() {
	if [ `sudo -l -U "$1" | grep -c 'is not allowed to run sudo'` -eq 0 ]; then
		echo "1"
	else
		echo "0"
	fi
}

# @param '<username> <password>'
function getToken() {
	echo -n "$1" | md5sum | awk '{ printf("%s", $1) }'
}

# @param token
function getUser() {
	cat "logins.txt" |
		while read line; do
			if [ `getToken "$line"` = "$1" ]; then
				echo "$line" | awk '{ print $1 }'
				
				return 0
			fi
		done
	return 1
}

token=`echo "$HTTP_COOKIE" | grep -P -o '(?<=token=)[^;]+'` # token de login
user=`getUser "$token"`

# [restart]
declare -A get_info
read tmp1 tmp2 <<< `echo "$QUERY_STRING" | cut -d "&" -f 1 | awk -F= '{ print $1 " " $2 }'`
get_info["$tmp1"]="$tmp2"

if [ `isSudoer "$user"` == "1" ]; then
	if [ "${get_info[restart]}" = "true" ]; then
		# restart
		logger -p local7.info "User $user restarted the server."
		
		echo "content-type: text/plain"
		echo
		echo "{\"result\":\"ok\"}"
		
		sudo reboot
		
	else
		# stop
		logger -p local7.info "User $user stopped the server."
		
		echo "content-type: text/plain"
		echo
		echo "{\"result\":\"ok\"}"
		
		sudo shutdown now
	fi
else
	echo "Status: 401"
	echo "content-type: text/plain"
	echo
	echo "{\"err\":\"Operation not permitted\"}"
fi