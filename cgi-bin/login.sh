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
	user_readed=`getUserPassword "$1"`
	if [ -z "$user_readed" ]; then
		# token invàl·lid
		logger -p local7.warning "$REMOTE_ADDR have an invalid token."
		invalidLogin
		exit 1 # falta login
	else
		# token vàl·lid
		read user password <<< `echo "$user_readed"`
		if [ $# -gt 1 ]; then
			# hi ha comanda a executar
			shift # elimina el token dels arguments
			tmp=`mktemp`
			echo "$password" | su -l "$user" -c "$*" 2>"$tmp" # obtè l'execució i elimina 'Password: '
			cut -c 11- "$tmp" # elimina el "Password: "
			logger -p local7.info "User $user running '$*'..."
		else
			# només era login
			logger -p local7.info "User $user logged in using token."
		fi
		exit 0 # tot ok
	fi
fi