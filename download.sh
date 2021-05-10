#!/bin/bash
set -e

url="$1"
if [ -z "$url" ]; then 1>&2 echo 'missing 1st argument: url'; exit 1; fi
dest_file="$2"
if [ -z "$dest_file" ]; then 1>&2 echo 'missing 2nd argument: dest_file'; exit 1; fi

# call wget, clean up $dest_file if it failed
wget --header='User-Agent: mfdz/gtfs-hub' \
	-c "$url" -O "$dest_file" \
	|| (code=$?; rm -f "$dest_file"; exit $code)
