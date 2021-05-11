#!/bin/bash
set -e
set -o pipefail
set -x

name=$1
gtfs_dir=$2

if [ "$1" == "SPNV-BW" ]; then
  1>&2 echo "SPNV-BW routes.txt: filling missing agency_id values"
  mlr --csv put -S '$agency_id == "" { $agency_id = "00" }' "$gtfs_dir/routes.txt" | sponge "$gtfs_dir/routes.txt"
fi
