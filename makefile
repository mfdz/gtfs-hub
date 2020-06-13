
# To add a new merged feed, add it's shortname here and define the variable definitions and targets as for HBG below
MERGED = hbg
# To add a new filtered feed, add it's shortname below and add a DELFI.<shortname>.rule filter rule in config/gtfs-rules.
# NOTE: currently shape enhancement only is done using bw-buffered.osm
FILTERED = BW
all : $(MERGED:%=data/gtfs/%.merged.gtfs.zip) $(FILTERED:%=data/gtfs/DELFI.%.with_shapes.gtfs.zip)
.PHONY : all

# Shortcuts for the (dockerized) transform/merge tools. 
MERGE = docker run -v $(HOST_DATA):/data --rm mfdz/otp-data-tools java -Xmx18g -jar one-busaway-gtfs-merge/onebusaway-gtfs-merge-cli.jar --file=stops.txt --duplicateDetection=identity 
TRANSFORM = docker run -v $(HOST_DATA):/data --rm mfdz/otp-data-tools java -Xmx20g -jar one-busaway-gtfs-transformer/onebusaway-gtfs-transformer-cli.jar 
PFAEDLE = docker run -v "$(HOST_DATA)":/data:rw --rm mfdz/pfaedle

# For every merged dataset, it's composing feeds should be listed.
# At first, we define a variable with all feed names, which subsquently gets expanded
# to the complete paths
HBG = naldo.filtered VGC.filtered VVS.with_shapes.filtered
HBG_FILES = $(HBG:%=data/gtfs_validated/%.gtfs.zip)
data/gtfs/hbg.merged.gtfs.zip: $(HBG_FILES)
	$(MERGE) $^ /$@

data/gtfs_validated/%.filtered.gtfs.zip: data/gtfs_validated/%.gtfs.zip data/gtfs-rules/%.rule
	$(TRANSFORM) --transform=/data/gtfs-rules/$*.rule /data/gtfs_validated/$*.gtfs.zip /$@

# As we extract from DELFI and not only do patches, we check for the master file
# As target is a folder, we touch to explicitly set modified timestamp
data/gtfs/DELFI.%.filtered.gtfs: data/gtfs/DELFI.gtfs.zip data/gtfs-rules/DELFI.%.rule
	$(TRANSFORM) --transform=/data/gtfs-rules/DELFI.$*.rule /data/gtfs/DELFI.gtfs.zip /$@ && touch data/gtfs/DELFI.$*.filtered.gtfs/

# Apply pfaedle inplace and zip resulting files
data/gtfs/DELFI.%.with_shapes.gtfs.zip: data/gtfs/DELFI.%.filtered.gtfs
	$(PFAEDLE) --inplace -D -x /data/osm/bw-buffered.osm /data/gtfs/DELFI.$*.filtered.gtfs && zip -j $@ data/gtfs/DELFI.$*.filtered.gtfs/*.txt
