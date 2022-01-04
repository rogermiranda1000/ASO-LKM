#!/bin/bash
function requestLogin() {
	echo "content-type: text/html; charset=utf-8"
	echo
	cat "src/login.html"
}

function invalidLogin() {
	html=`requestLogin`
	echo "${html::-15}" # remove "</body></html>"
	echo "<script>app.appendError('Token invàl·lid; has de tornar a fer login.');</script>"
	echo "</body></html>"
}

# Obtè el token d'usuari
# @param '<username> <password>'
function getToken() {
	echo -n "$1" | md5sum | awk '{ printf("%s", $1) }'
}

# Obtè el username i password a partir d'un token
# @param token
function getUserPassword() {
	cat "logins.txt" |
		while read line; do
			if [ `getToken "$line"` = "$1" ]; then
				echo "$line"
				return 0
			fi
		done
	
	return 1 # not found
}

if [ $# -eq 0 ]; then
	# no hi ha token -> s'ha de fer login
	requestLogin
	exit 1 # falta login
else
	# hi ha token; validar
	user=`getUserPassword "$1"`
	if [ -z "$user" ]; then
		# token invàl·lid
		echo "$REMOTE_ADDR have an invalid token." >> /var/log/website_manager.log
		invalidLogin
		exit 1 # falta login
	else
		# token vàl·lid
		if [ $# -gt 1 ]; then
			# hi ha comanda a executar
			echo "executing..." > /dev/null
		else
			# només era login
			echo "$user" | awk -v date=`date '+%d-%m-%Y_%H:%M'` '{ gsub(/_/," ",date); print "User " $1 " logged in using token [" date "]" }' >> /var/log/website_manager.log
		fi
		exit 0 # tot ok
	fi
fi