#!/bin/bash

function getClass() {
	json=`sudo iptables -L "$1" | awk 'FNR > 2{ printf("{\"action\":\"%s\",\"protocol\":\"%s\",\"ip_src\":\"%s\",\"ip_dst\":\"%s\",\"extra\":\"", $1, $2, $4, $5); for(i=6; i<NF; i++) printf("%s ", $i); printf("\"},") }'`
	if [ -z "$json" ]; then
		echo -n "[]"
	else
		echo -n "[${json::-1}]"
	fi
}

# class, action, ip_src, ip_dst, port_src, port_dst, protocol
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

if [ "$REQUEST_METHOD" != "GET" ] || [ -z "${get_info[action]}"]; then
	# list all filters
	echo "content-type: text/plain"
	echo
	echo -n "{\"filters\": [{\"class\":\"INPUT\",\"filters\":"
	getClass "INPUT"
	echo -n "},{\"class\":\"FORWARD\",\"filters\":"
	getClass "FORWARD"
	echo -n "},{\"class\":\"OUTPUT\",\"filters\":"
	getClass "OUTPUT"
	echo "}]}"
else
	echo "content-type: text/plain"
	echo
	echo "TODO"
fi

