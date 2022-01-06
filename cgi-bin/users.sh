#!/bin/bash

# @param user
function isSudoer() {
	if [ `sudo -l -U "$1" | grep -c 'is not allowed to run sudo'` -eq 0 ]; then
		echo "true"
	else
		echo "false"
	fi
}

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

# action [add/remove/set], [setter [superuser]], [setter_value], user, [password]
declare -A post_info
read post_data
read tmp1 tmp2 <<< `echo "$post_data" | cut -d "&" -f 1 | awk -F= '{ print $1 " " $2 }'`
post_info["$tmp1"]="$tmp2"
read tmp1 tmp2 <<< `echo "$post_data" | cut -d "&" -f 2 | awk -F= '{ print $1 " " $2 }'`
post_info["$tmp1"]="$tmp2"
read tmp1 tmp2 <<< `echo "$post_data" | cut -d "&" -f 3 | awk -F= '{ print $1 " " $2 }'`
post_info["$tmp1"]="$tmp2"
read tmp1 tmp2 <<< `echo "$post_data" | cut -d "&" -f 4 | awk -F= '{ print $1 " " $2 }'`
post_info["$tmp1"]="$tmp2"

if [ "$REQUEST_METHOD" != "POST" ] || [ -z "${post_info[action]}" ]; then
	# list all users
	users=""
	while read -r user; do
		sudoer=`isSudoer "$user"`
		users=`echo -n "$users{\"username\":\"$user\",\"superuser\":$sudoer},"`
	done <<< `cut -f1 -d: /etc/passwd`
	
	echo "content-type: text/plain"
	echo
	if [ -z "$users" ]; then
		echo "{\"users\":[]}"
	else
		echo "{\"users\":[${users::-1}]}"
	fi
else
	user=`getUser`
	if [ `isSudoer "$user"` = "false" ] && [ "${post_info[action]}" != "add" ] && [ "$user" != "${post_info[user]}" ] && [ "${post_info[action]}" != "set" ]; then
		# si es vol editar un usuari o eliminar un usuari que no és ell mateix has de ser root
		echo "Status: 401"
		echo "content-type: text/plain"
		echo
		echo "{\"err\": \"invalid token\"}"
		exit 1
	fi
	
	case "${post_info[action]}" in
		"add" )
			# logger ja s'afegeix a create_user_post.sh
			
			echo "content-type: text/plain"
			echo
			curl -d "username=${post_info[user]}&password=${post_info[password]}" -H "Content-Type: application/x-www-form-urlencoded" -X POST http://localhost/create_user_post.sh
			;;
			
		"remove" )
			sudo userdel -r "${post_info[user]}"
			
			logger -p local7.info "User $user removed ${post_info[user]}."
			
			echo "content-type: text/plain"
			echo
			echo "{\"msg\": \"deleted\"}"
			;;
		
		"set" )
			if [ "${post_info[setter]}" = "superuser" ]; then
				if [ "${post_info[setter_value]}" = "true" ]; then
					sudo usermod -aG sudo "${post_info[user]}" # add user to sudoers
				else
					sudo deluser "${post_info[user]}" sudo >/dev/null # remove user from sudoers
				fi
				
				logger -p local7.info "User $user setted ${post_info[user]}'s permissions."
				
				echo "content-type: text/plain"
				echo
				echo "{\"msg\": \"superuser setted\"}"
			else
				echo "Status: 400"
				echo "content-type: text/plain"
				echo
				echo "{\"err\": \"invalid setter\"}"
			fi
			
			;;
		
		*)
			echo "Status: 400"
			echo "content-type: text/plain"
			echo
			echo "{\"err\": \"invalid action\"}"
	esac
fi

