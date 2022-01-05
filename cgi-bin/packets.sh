#!/bin/bash

function getClass() {
	json=`sudo iptables -L "$1" | awk 'FNR > 2{ printf("{\"action\":\"%s\",\"protocol\":\"%s\",\"ip_src\":\"%s\",\"ip_dst\":\"%s\"", $1, $2, $4, $5); for(i=6; i<=NF; i++) { split($i,v,":"); if (length(v[2]) > 0) printf(",\"%s\":\"%s\"", v[1], v[2]); } printf("},") }'`
	if [ -z "$json" ]; then
		echo -n "[]"
	else
		echo -n "[${json::-1}]"
	fi
}

# do [A/D], class [INPUT/FORWARD/OUTPUT], action [DROP/ACCEPT], ip_src, ip_dst, port_src, port_dst, protocol
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
read tmp1 tmp2 <<< `echo "$QUERY_STRING" | cut -d "&" -f 8 | awk -F= '{ print $1 " " $2 }'`
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
	cmd="sudo iptables -${get_info[do]} ${get_info[class]}"
	if [ ! -z "${get_info[ip_src]}" ]; then
		cmd=`echo "$cmd -s ${get_info[ip_src]}"`
	fi
	if [ ! -z "${get_info[ip_dst]}" ]; then
		cmd=`echo "$cmd -d ${get_info[ip_dst]}"`
	fi
	if [ ! -z "${get_info[protocol]}" ]; then
		cmd=`echo "$cmd -p ${get_info[protocol]}"`
	fi
	if [ ! -z "${get_info[port_src]}" ]; then
		cmd=`echo "$cmd --sport ${get_info[port_src]}"`
	fi
	if [ ! -z "${get_info[port_dst]}" ]; then
		cmd=`echo "$cmd --dport ${get_info[port_dst]}"`
	fi
	`echo "$cmd -j ${get_info[action]}"` # execute command
	
	sudo sh -c 'iptables-save > /etc/iptables.conf' # persist changes
	
	echo "content-type: text/plain"
	echo
	echo "{\"msg\":\"done\"}"
	
fi

