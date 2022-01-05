#!/bin/bash

function getUserCron() {
	cron=`sudo crontab -u "$1" -l | grep -v '^#'`
	
	if [ -z "$cron" ] || [ `echo "$cron" | grep -c '^no crontab for '` -eq 1 ]; then
		# no crontab file
		return 0
	fi
	
	# list tasks
	data=`echo "$cron" | awk -v user="$1" '{ printf("{\"user\":\"%s\",\"minute\":\"%s\",\"hour\":\"%s\",\"m_day\":\"%s\",\"month\":\"%s\",\"w_day\":\"%s\",\"script\":\"", user, $1, $2, $3, $4, $5); for(i=6; i<=NF; i++) printf("%s ", $i); printf("\"},") }'`
	echo "${data::-1}" # remove last ','
}

# minute, hour, m_day, month, w_day, script
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
	# add task
	# TODO
	echo "content-type: text/plain"
	echo
	echo "{\"msg\": \"added\"}"
fi

