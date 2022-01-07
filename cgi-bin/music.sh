#!/bin/bash

# playlist, song, action
declare -A get_info
read tmp1 tmp2 <<< `echo "$QUERY_STRING" | cut -d "&" -f 1 | awk -F= '{ print $1 " " $2 }'`
get_info["$tmp1"]="$tmp2"
read tmp1 tmp2 <<< `echo "$QUERY_STRING" | cut -d "&" -f 2 | awk -F= '{ print $1 " " $2 }'`
get_info["$tmp1"]="$tmp2"

if [ -z "${get_info[playlist]}" ] && [ -z "${get_info[song]}" ]; then
	# list playlists
	
	if [ `ps aux | grep mpg123` -lt 2 ]; then
		# music player online?
		echo "content-type: text/plain"
		echo
		echo "{\"stopped\":\"true\"}"
		exit 1
	fi
	
	# get playlists
	content=""
	while read -r file; do
		is_content="0"
		content="$content{\"playlist\":\"$file\",\"files\":["
		while read -r line; do
			if [ "$line" != '' ]; then
				is_content="1"
				content="$content{\"path\":\"$route$line\"},"
			fi
		done <<< `cat "/var/www/cgi-bin/playlists/$file"`
		if [ "$is_content" = "1" ]; then
			content="${content::-1}"
		fi
		content="$content]},"
	done <<< `ls -la /var/www/cgi-bin/playlists | awk '{ print $9 }' | tail -n +4`
	
	echo "content-type: text/plain"
	echo
	if [ -z "$content" ]; then
		echo "{\"stopped\":\"false\",\"playlists\":[]}"
	else
		echo "{\"stopped\":\"false\",\"playlists\":[${content::-1}]}"
	fi
else
	echo "Status: 401"
	echo "content-type: text/plain"
	echo
	echo "{\"err\":\"Operation not permitted\"}"
fi