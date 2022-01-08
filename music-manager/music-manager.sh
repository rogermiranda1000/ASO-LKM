#!/bin/bash

write_pipe=`mktemp`
read_pipe=`mktemp`
playlists="/home/music-manager/playlists" # todo music-manager user

music_manager_solicitations="/home/music-manager/music_manager_solicitations"
music_manager_info="/home/music-manager/music_manager_info"

touch "$music_manager_info"
chmod 644 "$music_manager_info" # only I can edit; the others can read

mkfifo -m 0622 "$music_manager_solicitations"
mkfifo -m 0622 "$read_pipe"

trap "rm $music_manager_solicitations $music_manager_info $write_pipe $read_pipe" EXIT # delete the named pipes on exit

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

function updateContents() {
	echo -n "{\"playlists\":" > "$music_manager_info"
	getPlaylists >> "$music_manager_info"
	echo "}" >> "$music_manager_info" # TODO add more
}

updateContents
ps aux | grep mpg123 | awk '{ print $2 }' | xargs sudo kill -9 $1 2>/dev/null # kill previous mpg123 (if any)
while true; do
	# han matat el programa?
	if [ `ps aux | grep -c mpg123` -lt 2 ]; then # ha de ser 2 perqué el grep ja conta com 1
		logger -p local7.info "No s'ha trobat el programa mpg123, llençant-lo de nou..."
		sudo sh -c "mpg123 -R --fifo $write_pipe > $read_pipe &"
	fi
	
	read -t 5 var < "$music_manager_solicitations" # read ya hace de sleep
	ret=$?
	if [ $? -eq 0 ]; then
		# han hablado
		case `echo "$var" | awk '{ print $1 }'` in
			"p" )
				# play/pause
				sudo sh -c "echo 'p' > $write_pipe"
				;;
			
			"l" )
				# load playlist
				msg=`echo -n "loadlist 1 $playlists/"; echo "$var" | awk '{ print $2 }'`
				sudo sh -c "echo $msg > $write_pipe"
				;;
			
			*)
				echo "$var"
		esac
	fi
done