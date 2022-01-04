#!/bin/bash
token=`echo "$HTTP_COOKIE" | grep -P -o '(?<=token=).+(?=(; )|$)'`
./login.sh "$token"

#echo "" | su -l rogermiranda1000 -c 'whoami'
