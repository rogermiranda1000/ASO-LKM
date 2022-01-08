#!/bin/bash

read_pipe=`mktemp`
playlists="/home/music-manager/playlists" # todo music-manager user

music_manager_solicitations="/home/music-manager/music_manager_solicitations"
music_manager_info="/home/music-manager/music_manager_info"

sudo rm -f "$music_manager_solicitations" "$music_manager_info" "$read_pipe"
trap "sudo rm -f $music_manager_solicitations $music_manager_info $read_pipe" EXIT # delete the named pipes on exit

touch "$music_manager_info"
chmod 644 "$music_manager_info" # only I can edit; the others can read

mkfifo -m 0622 "$music_manager_solicitations"
mkfifo -m 0622 "$read_pipe"

function getPlaylists() {
	content=""
	while read -r file; do
		is_content="0"
		content="$content{\"playlist\":\"$file\",\"files\":["
		while read -r line; do
			if [ "$line" != '' ]; then
				is_content="1"
				content="$content{\"path\":\"$route$line\"},"
			fi
		done <<< `cat "$playlists/$file.play"`
		if [ "$is_content" = "1" ]; then
			content="${content::-1}"
		fi
		content="$content]},"
	done <<< `ls -la "$playlists" | awk '{ print $9 }' | tail -n +4 | grep -o -P '.+(?=\.play)'`
	
	if [ -z "$content" ]; then
		echo -n "[]"
	else
		echo -n "[${content::-1}]"
	fi
}

time="0/0"
status="0" # 0: stopped, 1: paused, 2: unpaused
function updateContents() {
	echo -n "{\"playlists\":" > "$music_manager_info"
	getPlaylists >> "$music_manager_info"
	echo ",\"time\":\"$time\",\"status\":$status}" >> "$music_manager_info" # TODO add more
}

# @param mpg123's line
function getTime() {
	case `echo "$1" | awk '{ print $1 }'` in
		"@F" )
			# @F <frame> <remaining frames> <second> <remaining seconds>
			time=`echo "$1" | awk '{ print $4 "/" ($4+$5) }'`
			echo "New time: $time"
			;;
		
		"@P" )
			status=`echo "$1" | awk '{ print $2 }'`
			echo "New status: $status"
			;;
		
		* )
			if [ "${1:0:1}" = "@" ]; then
				echo "Unknown: '$1'" # només comandes musicals
			fi
			;;
	esac
}

function closePlayers() {
	while read -r players; do
		sudo sh -c "echo 'q' > /proc/$players/fd/3" # quit
		sudo kill -SIGINT "$players" 2>/dev/null
	done <<< `ps aux | grep mpg123 | awk '{ print $2 }'`
}

pid=""
closePlayers
updateContents
while true; do
	# music data
	i=0
	while false; do
		#read -t 0.5 -s var < "$read_pipe"
		#ret=$?
		ret=1
		
		if [ $ret -ne 0 ]; then
			break
		fi
		
		getTime "$var"
		let "i++"
		
		if [ $i -gt 10 ]; then
			break
		fi
	done
	
	updateContents # actualitza el contingut
	
	# user data
	read -t 0.5 -s var < "$music_manager_solicitations" # read ya hace de sleep
	ret=$?
	if [ $ret -eq 0 ]; then
		# han hablado
		case `echo "$var" | awk '{ print $1 }'` in
			"p" )
				# play/pause
				#sudo kill -SIGUSR1 "$pid"
				sudo sh -c "echo '.' > /proc/$pid/fd/3"
				;;
				
			"n" )
				sudo sh -c "echo 'f' > /proc/$pid/fd/3"
				;;
				
			"b" )
				sudo sh -c "echo 'd' > /proc/$pid/fd/3"
				;;
			
			"l" )
				# load playlist
				closePlayers
				playlist=`echo -n "$playlists/"; echo "$var.play" | awk '{ print $2 }'`
				#sudo mpg123 -C --list "$playlist" --listentry 1 --continue &
				sudo mpg123 -C /home/rogermiranda1000/songs/ARK-*.mp3 &
				
				# get PID
				try=0
				pid=""
				while [ -z "$pid" ] && [ $try -lt 10 ]; do
					sleep 1
					pid=`pidof mpg123`
					let "try++"
				done
				
				echo "loading playlist... PID=$pid"
				;;
			
			* )
				echo "Unknown: '$var'"
				;;
		esac
	fi
done