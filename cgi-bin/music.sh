#!/bin/bash

music_manager_solicitations="/home/music-manager/music_manager_solicitations"
music_manager_info="/home/music-manager/music_manager_info"

# playlist, song, action [-/open/load/toggle/next/back]
declare -A get_info
read tmp1 tmp2 <<< `echo "$QUERY_STRING" | cut -d "&" -f 1 | awk -F= '{ print $1 " " $2 }'`
get_info["$tmp1"]="$tmp2"
read tmp1 tmp2 <<< `echo "$QUERY_STRING" | cut -d "&" -f 2 | awk -F= '{ print $1 " " $2 }'`
get_info["$tmp1"]="$tmp2"

if [ -z "${get_info[playlist]}" ] && [ -z "${get_info[song]}" ] && [ -z "${get_info[action]}" ]; then
	# list playlists
	
	echo "content-type: text/plain"
	echo
	if [ `ps aux | grep -c 'music-manager.sh'` -lt 2 ]; then
		# music player online?
		echo "{\"stopped\":true}"
		exit 1
	fi
	
	echo -n "{\"stopped\":false,\"data\":"
	cat "$music_manager_info" | tr -d '\n'
	echo "}"
else
	case "${get_info[action]}" in
		"open" )
			sudo systemctl restart music-manager.service
			;;
		"load" )
			echo "l ${get_info[playlist]}" > "$music_manager_solicitations"
			;;
		"toggle" )
			echo "p" > "$music_manager_solicitations"
			;;
		"next" )
			echo "n" > "$music_manager_solicitations"
			;;
		"back" )
			echo "b" > "$music_manager_solicitations"
			;;
		*)
			echo "Status: 400"
			echo "content-type: text/plain"
			echo
			echo "{\"err\":\"Operation unknown\"}"
			exit 1
			;;
	esac
	
	echo "content-type: text/plain"
	echo
	echo "{\"msg\":\"ok\"}"
fi