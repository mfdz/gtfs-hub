#!/bin/bash
set -e
set -o pipefail
set -x

name=$1
gtfs_dir=$2

if [ "$1" == "DELFI" ]; then
  1>&2 echo "patching DELFI $gtfs_dir/agency.txt"
  sed -i 's/"","Europe/"https:\/\/www.delfi.de\/","Europe/' "$gtfs_dir/agency.txt"
fi

if [ "$1" == "VVS" ]; then
  1>&2 echo "deleting broken VVS $gtfs_dir/transfers.txt"
  rm "$gtfs_dir/transfers.txt"
fi