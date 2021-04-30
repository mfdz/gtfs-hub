#!/bin/bash
set -e

url="$1"
if [ -z "$url" ]; then 1>&2 echo 'missing 1st argument: url'; exit 1; fi
dest_file="$2"
if [ -z "$dest_file" ]; then 1>&2 echo 'missing 2nd argument: dest_file'; exit 1; fi

if [ -z "$OSMIUM_UPDATE" ]; then 1>&2 echo 'missing env var: OSMIUM_UPDATE'; exit 1; fi

set -x
# call wget, clean up $dest_file if it failed
if [ -f "$dest_file" ]; then
	$OSMIUM_UPDATE
else
	./download.sh "$url" "$dest_file"
fi
