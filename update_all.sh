#!/bin/bash
set -e
set -o pipefail
set -x

export DATA_DIR=/var/data

if [ ! -f $DATA_DIR//osm/dach-latest.osm.pbf ]; then
	echo "Updating OSM..."
	./update_osm.sh
fi
echo "Updating GTFS..."
./update_gtfs.sh
echo "Preparing transformation rules"
cp makefile /var/
mkdir $DATA_DIR/gtfs-rules/
cp -p config/gtfs-rules/* $DATA_DIR/gtfs-rules/
pushd /var/
echo "Filter and merge GTFS files"
make
# Copy validated gtfs files to download dir, as well as merged feeds, but only if newer than existing
cp -p -u $DATA_DIR/gtfs_validated/*.zip $DATA_DIR/www/
cp -p -u $DATA_DIR/gtfs/*.merged.gtfs.zip $DATA_DIR/www/
popd