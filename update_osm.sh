export OSM_DIR=$DATA_DIR/osm
export OUT_DIR=$DATA_DIR/www
# HOST_DATA should be set 

mkdir -p $OSM_DIR
cp config/osm/* $OSM_DIR
ls $OSM_DIR

# Download or update OSM files
if [ ! -f "$OSM_DIR/alsace-latest.osm.pbf" ]; then
	echo 'Download alsace-latest.osm.pbf...'
    curl https://download.geofabrik.de/europe/france/alsace-latest.osm.pbf > $OSM_DIR/alsace-latest.osm.pbf
else
	echo 'Update alsace-latest.osm.pbf...'
	docker run --rm -v $HOST_DATA/osm:/osm mfdz/pyosmium pyosmium-up-to-date /osm/alsace-latest.osm.pbf
fi

if [ ! -f "$OSM_DIR/dach-latest.osm.pbf" ]; then
	echo 'Download dach-latest.osm.pbf...'
    curl https://download.geofabrik.de/europe/dach-latest.osm.pbf > $OSM_DIR/dach-latest.osm.pbf
else
	echo 'Update dach-latest.osm.pbf...'
	docker run --rm -v $HOST_DATA/osm:/osm mfdz/pyosmium pyosmium-up-to-date /osm/dach-latest.osm.pbf
fi

echo 'Extract from PBF using poly file ...'
docker run --rm -v $HOST_DATA/osm:/osm mfdz/pyosmium osmium extract -p /osm/bw_buffered.poly --no-progress -o /osm/alsace-extracted.osm.pbf -O /osm/alsace-latest.osm.pbf
docker run --rm -v $HOST_DATA/osm:/osm mfdz/pyosmium osmium extract -p /osm/bw_buffered.poly --no-progress -o /osm/dach-extracted.osm.pbf -O /osm/dach-latest.osm.pbf

echo 'Set park_ride tag for well known parkings and apply diversion patches ...'
docker run --rm -v $HOST_DATA/osm:/osm mfdz/osmosis:0.47-1-gd370b8c4 --read-pbf /osm/dach-extracted.osm.pbf --tt file=/osm/park_ride_transform.xml stats=/osm/park_ride_stats.log --tt file=/osm/diversions.xml stats=/osm/diversions.log --write-pbf /osm/dach-extracted-patched.osm.pbf

echo 'Patched DACH extract, now merging with alsace...'
docker run --rm -v $HOST_DATA/osm:/osm mfdz/pyosmium osmium merge -o /osm/bw-buffered.osm.pbf -O /osm/alsace-extracted.osm.pbf /osm/dach-extracted-patched.osm.pbf

echo 'Move bw-buffered.osm.pbf to /var/data/www'
mv $OSM_DIR/bw-buffered.osm.pbf $OUT_DIR/bw-buffered.osm.pbf

echo 'Extract osm format for GTFS shape enhancement (As long as pfaedle does not suport osm.pbf directly)'
docker run --rm -v $HOST_DATA/osm:/osm mfdz/pyosmium osmium cat /osm/bw-buffered.osm.pbf -o /osm/bw-buffered.osm -O
docker run --rm -v $HOST_DATA/osm:/osm mfdz/pyosmium osmium cat /osm/dach-latest.osm.pbf -o /osm/dach-latest.osm -O

