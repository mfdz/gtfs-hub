#!/bin/bash
set -e
set -o pipefail

name=$1
gtfs_dir=$2

if [ "$1" == "VVS" ]; then
  1>&2 echo "deleting broken VVS $gtfs_dir/transfers.txt"
  set -x
  rm "$gtfs_dir/transfers.txt"
  set +x
fi
