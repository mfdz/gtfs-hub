
# To add a new merged feed, add it's shortname here and define the variable definitions and targets as for HBG below
MERGED = hbg
# To add a new filtered feed, add it's shortname below and add a DELFI.<shortname>.rule filter rule in config/gtfs-rules.
# NOTE: currently shape enhancement only is done using bw-buffered.osm
FILTERED = BW
all : $(MERGED:%=${DATA_DIR}/gtfs/%.merged.gtfs.zip) $(FILTERED:=${DATA_DIR}/gtfs/DELFI.%.with_shapes.gtfs.zip)
.PHONY : all

# Shortcuts for the (dockerized) transform/merge tools. 
MERGE = docker run -v $(HOST_DATA):/data --rm mfdz/otp-data-tools java -Xmx14g -jar one-busaway-gtfs-merge/onebusaway-gtfs-merge-cli.jar --file=stops.txt --duplicateDetection=identity 
TRANSFORM = docker run -v $(HOST_DATA):/data --rm mfdz/otp-data-tools java -Xmx12g -jar one-busaway-gtfs-transformer/onebusaway-gtfs-transformer-cli.jar 
PFAEDLE = docker run -v "$(HOST_DATA)":/data:rw --rm mfdz/pfaedle

# For every merged dataset, it's composing feeds should be listed.
# At first, we define a variable with all feed names, which subsquently gets expanded
# to the complete paths
HBG = naldo.filtered VGC.filtered VVS.filtered
HBG_FILES = $(HBG:%=${DATA_DIR}/gtfs_validated/%.gtfs.zip)
${DATA_DIR}/gtfs/hbg.merged.gtfs.zip: $(HBG_FILES)
	$(MERGE) $^ /$@

# As we extract from DELFI and not only do patches, we check for the master file
${DATA_DIR}/gtfs/DELFI.%.filtered.gtfs: ${DATA_DIR}/gtfs/DELFI.gtfs.zip ${DATA_DIR}/gtfs-rules/DELFI.%.rule
	$(TRANSFORM) --transform=/data/gtfs-rules/DELFI.$*.rule /data/gtfs/DELFI.gtfs.zip /$@

# Apply pfaedle inplace and zip resulting files
${DATA_DIR}/gtfs/DELFI.%.with_shapes.gtfs.zip: ${DATA_DIR}/gtfs/DELFI.%.filtered.gtfs
	$(PFAEDLE) --inplace -D -x /data/osm/bw-buffered.osm /data/gtfs/DELFI.$*.filtered.gtfs && zip -j $@ ${DATA_DIR}/gtfs/DELFI.$*.filtered.gtfs/*.txt
