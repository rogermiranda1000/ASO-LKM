#!/bin/bash

token=`echo "$HTTP_COOKIE" | grep -P -o '(?<=token=)[^;]+'` # token de login (si en té)
if [ -z "$token" ]; then
	./login.sh; ret=$?
else
	./login.sh "$token"; ret=$?
fi

if [ $ret -ne 0 ]; then
	exit 0 # l'usuari ha de fer login; login.sh ja carrega la pàgina
fi

echo "content-type: text/html; charset=utf-8"
echo
cat "src/index.html"