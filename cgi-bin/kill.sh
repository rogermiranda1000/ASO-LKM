#!/bin/bash

token=`echo "$HTTP_COOKIE" | grep -P -o '(?<=token=)[^;]+'` # token de login
echo "content-type: text/html; charset=utf-8"
echo
echo -n "{\"result\":\""
tmp=`mktemp`
./login.sh "$token" kill -9 `echo $QUERY_STRING | awk -F= '{print $2}'` 2>"$tmp"
cat "$tmp"
echo "\"}"