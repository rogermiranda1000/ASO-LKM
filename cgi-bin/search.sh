#!/bin/bash
echo "content-type: text/html; charset=utf-8"
echo
echo -n "{\"results\":["

path=`echo "$QUERY_STRING" | awk -F= '{print $2}'`
route=`echo "$path" | grep -P -o '.*(?=/)'` # '/test/abc/d' > '/test/abc'
route="$route/"
path="${path:${#route}}" # '/test/abc/d' > 'd'

content=""
while read -r line; do
	content="$content{\"path\":\"$route$line\"},"
done <<< `sudo ls -la "$route" | awk '{ print $9 }' | grep -P "^$path"`
content=${content::-1}
echo "$content]}"