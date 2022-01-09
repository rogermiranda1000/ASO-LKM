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

declare -A get_info
read tmp1 tmp2 <<< `echo "$QUERY_STRING" | cut -d "&" -f 1 | awk -F= '{ print $1 " " $2 }'`
get_info["$tmp1"]="$tmp2"
read tmp1 tmp2 <<< `echo "$QUERY_STRING" | cut -d "&" -f 2 | awk -F= '{ print $1 " " $2 }'`
get_info["$tmp1"]="$tmp2"

if [ `isSudoer "$user"` == "1" ]; then
	if [ "${get_info[time]}" != '' ]; then
		# stop
		sudo kill -STOP "${get_info[pid]}" 2>/dev/null
		
		echo "content-type: text/plain"
		echo
		echo "{\"result\":\"stopped\"}"
		
		# s'ha de re-activar
		(sleep "${get_info[time]}"; sudo kill -CONT "${get_info[pid]}") &
		
		logger -p local7.info "User $user stopping PID ${get_info[pid]}..."
		
	else
		# the user is sudoer -> run kill always
		sudo kill -9 "${get_info[pid]}" 2>/dev/null
		
		echo "content-type: text/plain"
		echo
		echo "{\"result\":\"killed as sudo\"}"
		
		logger -p local7.info "User $user running 'kill -9 ${get_info[pid]}' as sudo..."
	fi
else
	# kill
	if [ -z "${get_info[time]}" ] && [ `./login.sh "$token" kill -9 "${get_info[pid]}" | grep -c 'Operation not permitted'` -eq 0 ]; then
		echo "content-type: text/plain"
		echo
		echo "{\"result\":\"killed\"}"
	else
		echo "Status: 401"
		echo "content-type: text/plain"
		echo
		echo "{\"err\":\"Operation not permitted\"}"
	fi
fi