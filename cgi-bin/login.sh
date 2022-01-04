#!/bin/bash
function requestLogin() {
	echo "content-type: text/html; charset=utf-8"
	echo
	cat "src/login.html"
}

function invalidLogin() {
	html=`requestLogin`
	echo "${html::-15}" # remove "</body></html>"
	echo "<div class=\"error\">Token invàl·lid; has de tornar a fer login.</div>"
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
else
	# hi ha token; validar
	if [ -z `getUserPassword "$1"`]; then
		# token invàl·lid
		invalidLogin
	else
		echo "content-type: text/html; charset=utf-8"
		echo
		# token vàl·lid
		if [ $# -gt 1 ]; then
			# hi ha comanda a executar
			echo "executing..."
		fi
	fi
fi