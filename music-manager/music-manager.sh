#!/bin/bash

read_pipe=`mktemp`
playlists="/home/music-manager/playlists" # todo music-manager user

music_manager_solicitations="/home/music-manager/music_manager_solicitations"
music_manager_info="/home/music-manager/music_manager_info"

ps aux | grep mpg123 | awk '{ print $2 }' | xargs sudo kill -9 $1 2>/dev/null # kill previous mpg123 (if any)
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
		done <<< `cat "$playlists/$file"`
		if [ "$is_content" = "1" ]; then
			content="${content::-1}"
		fi
		content="$content]},"
	done <<< `ls -la "$playlists" | awk '{ print $9 }' | tail -n +4`
	
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

updateContents
while true; do
	# han matat el programa?
	if [ `ps aux | grep -c mpg123` -lt 2 ]; then # ha de ser 2 perqué el grep ja conta com 1
		logger -p local7.info "No s'ha trobat el programa mpg123, llençant-lo de nou..."
		
		sudo sh -c "mpg123 -R --fifo $write_pipe &" # llença el programa en paralel; el programa llegirà de 'write_pipe' i printarà info a 'read_pipe'
	fi
	
	# music data
	i=0
	while true; do
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
				sudo sh -c "echo 'p' > $write_pipe"
				;;
			
			"l" )
				# load playlist
				msg=`echo -n "loadlist 3 $playlists/"; echo "$var" | awk '{ print $2 }'`
				sudo sh -c "echo $msg > $write_pipe"
				;;
			
			* )
				echo "Unknown: '$var'"
				;;
		esac
	fi
done