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
echo "content-type: text/html; charset=utf-8"
echo
echo -n "{\"result\":\""
user=`getUser "$token"`
pid=`echo "$QUERY_STRING" | awk -F= '{print $2}'`
if [ "$user" != '' ] && [ `isSudoer "$user"` == "1" ]; then
	# the user is sudoer -> run kill always
	sudo kill -9 "$pid"
	echo -n "killed as sudo"
	logger -p local7.info "User $user running 'kill -9 $pid' as sudo..."
else
	./login.sh "$token" kill -9 "$pid"
fi
echo "\"}"