#!/bin/bash

# Obtè el token d'usuari
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

user=`getUser`
if [ -z "$user" ]; then
	echo "Status: 401"
	echo "content-type: text/plain"
	echo
	echo "{\"err\": \"The current user don't have access to the processes.\"}"
else
	echo "content-type: text/plain"
	echo
	echo -n "{\"uptime\":\""
	uptime -p | cut -d' ' -f2- | tr -d '\n' # uptime en format humà, sense el 'up' del principi
	echo -n "\",\"disc_usage\":"
	df -h | grep '\s/$' | awk '{ printf("%.2f", $5/100) }'
	top_result=`top -bn1`
	# en la primera línea de 'top', surt al final 'load average: <avg 1>, <avg 2>, <avg 3>'
	# en la quarta línea de 'top', surt 'MiB Mem :    <MiB total> total,    <MiB free> free,     <MiB used> used'
	echo "$top_result" | awk 'NR==1{ printf(",\"average_cpu_usage\":%.2f", $(NF-2)) } NR==2{ count=$2 } NR==4{ printf(",\"ram_usage\":%.2f,\"processes\":[", $8 / $4) } NR>7{ printf("{\"pid\":%d,\"user\":\"%s\",\"status\":\"%s\",\"command\":\"%s\",\"cpu\":%.2f,\"mem\":%.2f}", $1, $2, $8, $12, $9/100, $10/100); if (NR-8 < count-1) {printf(",")} }'
	echo "]}"
fi