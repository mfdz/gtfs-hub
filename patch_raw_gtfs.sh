#!/bin/bash
set -e
set -o pipefail

name=$1
gtfs_dir=$2

if [ "$1" == "SPNV-BW" ]; then
  1>&2 echo "SPNV-BW routes.txt: filling missing agency_id values"
  set -x
  mlr --csv put -S '$agency_id == "" { $agency_id = "00" }' "$gtfs_dir/routes.txt" | sponge "$gtfs_dir/routes.txt"
  set +x
fi

if [ "$1" == "DELFI" ]; then
  1>&2 echo "DELFI agency.txt: filling missing agency_url values"
  set -x
  mlr --csv put -S '$agency_url == "" { $agency_url = "https://www.delfi.de/" }' "$gtfs_dir/agency.txt" | sponge "$gtfs_dir/agency.txt"
  # https://github.com/mfdz/GTFS-Issues/issues/71
  grep -v '"",' "$gtfs_dir/stop_times.txt" | sponge "$gtfs_dir/stop_times.txt"
  # https://github.com/mfdz/GTFS-Issues/issues/72
  grep -v '"de:08236:2590:2",' "$gtfs_dir/stop_times.txt" | sponge "$gtfs_dir/stop_times.txt"
  grep -v '"de:08316:6667:2:1",' "$gtfs_dir/stop_times.txt" | sponge "$gtfs_dir/stop_times.txt"
  grep -v '"de:08326:8324:90:",' "$gtfs_dir/stop_times.txt" | sponge "$gtfs_dir/stop_times.txt"
  grep -v '"de:09676:99310:90",' "$gtfs_dir/stop_times.txt" | sponge "$gtfs_dir/stop_times.txt"
  
  set +x
fi

if [ "$1" == "bwgesamt" ]; then
  1>&2 echo "bwgesamt stops.txt: deleting rows with duplicate stop_ids"
  set -x
  # https://github.com/mfdz/GTFS-Issues/issues/74
  grep -v '"de:09162:100_Parent","","München Hbf Gl. 27-36"' "$gtfs_dir/stops.txt" | sponge "$gtfs_dir/stops.txt"
  # https://github.com/mfdz/GTFS-Issues/issues/75
  tr -d '\r' < "$gtfs_dir/trips.txt" | sponge "$gtfs_dir/trips.txt"
  tr -d '\r' < "$gtfs_dir/stop_times.txt" | sponge "$gtfs_dir/stop_times.txt"
  # https://github.com/mfdz/GTFS-Issues/issues/77
  sed -i 's/,www/,http:\/\/www/g' "$gtfs_dir/agency.txt"
  sed -i 's/,"www/,"http:\/\/www/g' "$gtfs_dir/agency.txt"
  # https://github.com/mfdz/GTFS-Issues/issues/76
  sed -i 's/,,,"2/,"RB",,"2/' "$gtfs_dir/routes.txt"
  set +x
fi

