#!/bin/bash

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
	# list tasks
	cron=`crontab -l | grep -v '^#'`
	if [ -z "$cron" ] || [ `echo "$cron" | grep -c '^no crontab for '` -eq 1 ]; then
		# no crontab file
		echo "content-type: text/plain"
		echo
		echo "{\"tasks\": []}"
	else
		echo "content-type: text/plain"
		echo
		echo -n "{\"tasks\": ["
		data=`echo "$cron" | awk '{ printf("{\"minute\":\"%s\",\"hour\":\"%s\",\"m_day\":\"%s\",\"month\":\"%s\",\"w_day\":\"%s\",\"script\":\"", $1, $2, $3, $4, $5); for(i=6; i<=NF; i++) printf("%s ", $i); printf("\"},") }'`
		echo "${data::-1}]}"
	fi
else
	# add task
	# TODO
	echo "content-type: text/plain"
	echo
	echo "{\"msg\": \"added\"}"
fi

