#!/bin/bash
set -e

url="$1"
if [ -z "$url" ]; then 1>&2 echo 'missing 1st argument: url'; exit 1; fi
dest_file="$2"
if [ -z "$dest_file" ]; then 1>&2 echo 'missing 2nd argument: dest_file'; exit 1; fi

ua='User-Agent: mfdz/gtfs-hub'
etag_file="$dest_file.etag"

args=('-Lf' '-H' "$ua" '--compressed' '-z' "$dest_file" "$url" '-o' "$dest_file")
# call curl, clean up $dest_file if it failed
# `curl -C -` fails if the server doesn't support range requests, so we try again without `-C -`.
# todo: additionally use ETag headers to check if the remove file has changed
curl -s -C - "${args[@]}" || curl -sS "${args[@]}"
