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

function getUserCron() {
	cron=`sudo crontab -u "$1" -l | grep -v '^#' | grep -v '^$'`
	
	if [ -z "$cron" ] || [ `echo "$cron" | grep -c '^no crontab for '` -eq 1 ]; then
		# no crontab file
		return 0
	fi
	
	# list tasks
	data=`echo "$cron" | awk -v user="$1" '{ printf("{\"user\":\"%s\",\"minute\":\"%s\",\"hour\":\"%s\",\"m_day\":\"%s\",\"month\":\"%s\",\"w_day\":\"%s\",\"script\":\"", user, $1, $2, $3, $4, $5); for(i=6; i<=NF; i++) printf("%s ", $i); printf("\"},") }'`
	echo "${data::-1}" # remove last ','
}

# @param user
# @param line
function addCronData() {
	user="$1"
	shift
	(sudo crontab -u "$user" -l 2>/dev/null; echo "$*") | sudo crontab -u "$user" -
}

# @author https://stackoverflow.com/a/6265305/9178470
urldecode(){
	echo -e "$(sed 's/+/ /g;s/%\(..\)/\\x\1/g;')"
}

# action, minute, hour, m_day, month, w_day, script
declare -A get_info
read tmp1 tmp2 <<< `echo "$QUERY_STRING" | cut -d "&" -f 1 | awk -F= '{ print $1 " " $2 }'`
get_info["$tmp1"]="$tmp2"
read tmp1 tmp2 <<< `echo "$QUERY_STRING" | cut -d "&" -f 2 | awk -F= '{ print $1 " " $2 }'`
get_info["$tmp1"]="$tmp2"
read tmp1 tmp2 <<< `echo "$QUERY_STRING" | cut -d "&" -f 3 | awk -F= '{ print $1 " " $2 }'`
get_info["$tmp1"]="$tmp2"
read tmp1 tmp2 <<< `echo "$QUERY_STRING" | cut -d "&" -f 4 | awk -F= '{ print $1 " " $2 }'`
get_info["$tmp1"]="$tmp2"
read tmp1 tmp2 <<< `echo "$QUERY_STRING" | cut -d "&" -f 5 | awk -F= '{ print $1 " " $2 }'`
get_info["$tmp1"]="$tmp2"
read tmp1 tmp2 <<< `echo "$QUERY_STRING" | cut -d "&" -f 6 | awk -F= '{ print $1 " " $2 }'`
get_info["$tmp1"]="$tmp2"
read tmp1 tmp2 <<< `echo "$QUERY_STRING" | cut -d "&" -f 7 | awk -F= '{ print $1 " " $2 }'`
get_info["$tmp1"]="$tmp2"

if [ "$REQUEST_METHOD" != "GET" ] || [ -z "${get_info[script]}"]; then
	# list all tasks
	cron=""
	for user in `cut -f1 -d: /etc/passwd`; do
		tmp=`getUserCron "$user"`
		if [ "$tmp" != '' ]; then
			cron=`echo -n "$cron$tmp,"`
		fi
	done
	
	echo "content-type: text/plain"
	echo
	echo "{\"tasks\": [${cron::-1}]}"
else
	user=`getUser`
	if [ -z "$user" ]; then
		echo "Status: 401"
		echo "content-type: text/plain"
		echo
		echo "{\"err\": \"invalid token\"}"
		exit 1
	fi
	
	get_info['script']=`echo "${get_info[script]}" | urldecode`
	
	echo "content-type: text/plain"
	echo
	if [ "${get_info[action]}" = 'add' ]; then
		# add a task
		addCronData "$user" "${get_info[minute]} ${get_info[hour]} ${get_info[m_day]} ${get_info[month]} ${get_info[w_day]} ${get_info[script]}"
		echo "{\"msg\": \"added\"}"
	else
		# remove a task
		echo "{\"msg\": \"deleted\"}"
	fi
fi

