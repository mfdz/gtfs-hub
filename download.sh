#!/bin/bash
set -e

url="$1"
if [ -z "$url" ]; then 1>&2 echo 'missing 1st argument: url'; exit 1; fi
dest_file="$2"
if [ -z "$dest_file" ]; then 1>&2 echo 'missing 2nd argument: dest_file'; exit 1; fi

ua='User-Agent: mfdz/gtfs-hub'
etag_file="$dest_file.etag"

if test -e "$$dest_file"
then zflag="-z '$dest_file'"
else zflag=
fi

curl $zflag -Lf -H "$ua" --compressed -R "$url" '-o' "$dest_file"

# todo: support ETag headers
# args=('-Lf' '-H' "$ua" '--compressed' '-z' "$dest_file" -R "$url" '-o' "$dest_file")
# set -x
# # call curl, clean up $dest_file if it failed
# # `curl -C -` fails if the server doesn't support range requests, so we try again without `-C -`.
# # todo: additionally use ETag headers to check if the remove file has changed
# curl -C - "${args[@]}" || curl "${args[@]}"
