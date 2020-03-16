#!/bin/sh

./update_osm.sh
./update_gtfs.sh
cp makefile /var/
mkdir /var/data/gtfs-rules/
cp -p config/gtfs-rules/* /var/data/gtfs-rules/
pushd /var/
make
# Copy validated gtfs files to download dir, as well as merged feeds
cp -p /var/data/gtfs_validated/*.zip /var/data/www/
cp -p /var/data/gtfs/*.merged.zip /var/data/www/
popd