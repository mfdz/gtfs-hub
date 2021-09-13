#!/bin/bash
set -e

url="$1"
if [ -z "$url" ]; then 1>&2 echo 'missing 1st argument: url'; exit 1; fi
dest_file="$2"
if [ -z "$dest_file" ]; then 1>&2 echo 'missing 2nd argument: dest_file'; exit 1; fi

# Replace %CONNECT_FAHRPLANINFO_TOKEN% by corresponding env value, specified via make -e CONNECT_FAHRPLANINFO_TOKEN=xyz
url="${url/\%CONNECT_FAHRPLANINFO_TOKEN\%/$CONNECT_FAHRPLANINFO_TOKEN}"


ua='User-Agent: mfdz/gtfs-hub'
etag_file="$dest_file.etag"

if test -e "$$dest_file"
then zflag="-z '$dest_file'"
else zflag=
fi

#curl $zflag -Lf -H "$ua" --compressed -R "$url" '-o' "$dest_file"

# HVV has no permanent URL nor last-modfied info, so we download only if not existing
if [ "$dest_file" != "data/gtfs/HVV.gtfs.raw.zip" -o "$zflag"="" ]; then
	curl $zflag -Lf -H "$ua" --compressed -R "$url" '-o' "$dest_file"
fi

# todo: support ETag headers 
# todo: support md5
