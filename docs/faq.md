How to add a new region
--

1. Create a [poly file](https://wiki.openstreetmap.org/wiki/Osmosis/Polygon_Filter_File_Format) which covers the area to be cut out of osm DACH-file.
2. define a new target in makefile which performs the extraction
3. add the new GTFS feeds to gtfs-feeds.csv
4. define a new target for the merged file and register it as MERGED dataset
	
	
docker run --rm -e HOST_MOUNT=/home/mfdz/gtfs-hub -v /home/mfdz/gtfs-hub/data:/gtfs-hub/data/ -v /var/run/docker.sock:/var/run/docker.sock mfdz/gtfs-hub:local data/gtfs/hbg6.merged.with_flex.gtfs.zip >/home/mfdz/gtfs-hub/update_hbg.log
