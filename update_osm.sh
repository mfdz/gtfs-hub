export OSM_DIR=/var/data/osm
export OUT_DIR=/var/data/www
# HOST_DATA should be set 

mkdir -p $OSM_DIR

# Download or update OSM files
if [ ! -f "$OSM_DIR/alsace-latest.osm.pbf" ]; then
    curl https://download.geofabrik.de/europe/france/alsace-latest.osm.pbf > $OSM_DIR/alsace-latest.osm.pbf
else
	docker run -v $HOST_DATA/osm:/osm mfdz/pyosmium pyosmium-up-to-date /osm/alsace-latest.osm.pbf
fi

if [ ! -f "$OSM_DIR/dach-latest.osm.pbf" ]; then
    curl https://download.geofabrik.de/europe/dach-latest.osm.pbf > $OSM_DIR/dach-latest.osm.pbf
else
	docker run -v $HOST_DATA/osm:/osm mfdz/pyosmium pyosmium-up-to-date /osm/dach-latest.osm.pbf
fi


cp config/osm/* $OSM_DIR
# Extract from PBF using a poly file
docker run -v $HOST_DATA/osm:/osm mfdz/pyosmium ls -l /osm
docker run -v $HOST_DATA/osm:/osm mfdz/pyosmium osmium extract -p /osm/bw_buffered.poly --no-progress -o /osm/alsace-extracted.osm.pbf -O /osm/alsace-latest.osm.pbf
docker run -v $HOST_DATA/osm:/osm mfdz/pyosmium osmium extract -p /osm/bw_buffered.poly --no-progress -o /osm/dach-extracted.osm.pbf -O /osm/dach-latest.osm.pbf

# Set park_ride tag for well known parkings
docker run -v $HOST_DATA/osm:/osm mfdz/osmosis:0.47-1-gd370b8c4 --read-pbf /osm/dach-extracted.osm.pbf --tt file=/osm/park_ride_transform.xml stats=/osm/park_ride_stats.log --write-pbf /osm/dach-extracted-pr.osm.pbf

# Merge files
docker run -v $HOST_DATA/osm:/osm mfdz/pyosmium osmium merge -o /osm/bw-buffered.osm.pbf -O /osm/alsace-extracted.osm.pbf /osm/dach-extracted-pr.osm.pbf

# Extract osm format for GTFS shape enhancement
docker run -v $HOST_DATA/osm:/osm mfdz/pyosmium osmium cat /osm/bw-buffered.osm.pbf -o /osm/bw-buffered.osm -O

mv $OSM_DIR/bw-buffered.osm.pbf $OUT_DIR/bw-buffered.osm.pbf