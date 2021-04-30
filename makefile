HOST_MOUNT = $(PWD)
TOOL_CFG = /cfg
TOOL_DATA = /data

.PHONY : all
.DELETE_ON_ERROR:
.PRECIOUS: data/osm/alsace.osm.pbf data/osm/DACH.osm.pbf data/osm/bw-buffered.osm.pbf data/osm/bw-buffered.osm

# To add a new merged feed, add it's shortname here and define the variable definitions and targets as for HBG below
MERGED = hbg hbg2 ulm
# To add a new filtered feed, add it's shortname below and add a DELFI.<shortname>.rule filter rule in config/gtfs-rules.
# NOTE: currently shape enhancement only is done using bw-buffered.osm
FILTERED = BW
all : $(MERGED:%=data/gtfs/%.merged.gtfs.zip) $(FILTERED:%=data/gtfs/DELFI.%.with_shapes.gtfs.zip)

# Shortcuts for the (dockerized) transform/merge tools.
OSMIUM = docker run -i --rm -v $(HOST_MOUNT)/config/osm:$(TOOL_CFG) -v $(HOST_MOUNT)/data/osm:$(TOOL_DATA) mfdz/pyosmium osmium
OSMIUM_UPDATE = docker run -i --rm -v $(HOST_MOUNT)/data/osm:$(TOOL_DATA) mfdz/pyosmium pyosmium-up-to-date
OSMOSIS = docker run -i --rm -v $(HOST_MOUNT)/config/osm:$(TOOL_CFG) -v $(HOST_MOUNT)/data/osm:$(TOOL_DATA) mfdz/osmosis:0.47-1-gd370b8c4
MERGE = docker run -v $(HOST_DATA):/data --rm mfdz/otp-data-tools java -Xmx18g -jar one-busaway-gtfs-merge/onebusaway-gtfs-merge-cli.jar --file=stops.txt --duplicateDetection=identity 
TRANSFORM = docker run -v $(HOST_DATA):/data --rm mfdz/otp-data-tools java -Xmx20g -jar one-busaway-gtfs-transformer/onebusaway-gtfs-transformer-cli.jar 
PFAEDLE = docker run -v "$(HOST_DATA)":/data:rw --rm mfdz/pfaedle


# Baden-Württemberg OSM extract

data/osm/alsace.osm.pbf:
	$(info downloading Alsace OSM extract)
	OSMIUM_UPDATE="$(OSMIUM_UPDATE) $(TOOL_DATA)/$(@F)" ./update_osm.sh 'https://download.geofabrik.de/europe/france/alsace-latest.osm.pbf' '$@'

data/osm/DACH.osm.pbf:
	$(info downloading DACH OSM extract)
	OSMIUM_UPDATE="$(OSMIUM_UPDATE) $(TOOL_DATA)/$(@F)" ./update_osm.sh 'https://download.geofabrik.de/europe/dach-latest.osm.pbf' '$@'

data/osm/bw-extracted-from-%.osm.pbf: data/osm/%.osm.pbf
	$(info extracting buffered Baden-Württemberg from $(<F) OSM extract)
	$(OSMIUM) extract -p $(TOOL_CFG)/bw_buffered.poly -o $(TOOL_DATA)/$(@F) -O $(TOOL_DATA)/$(<F)

data/osm/bw-extracted-from-DACH.patched.osm.pbf: data/osm/bw-extracted-from-DACH.osm.pbf
	$(info setting park_ride tag for well-known parkings and applying diversion patches)
	$(OSMOSIS) --read-pbf $(TOOL_DATA)/$(<F) --tt file=$(TOOL_CFG)/park_ride_transform.xml stats=$(TOOL_DATA)/park_ride_stats.log --write-pbf $(TOOL_DATA)/$(@F)

data/osm/bw-buffered.osm.pbf: data/osm/bw-extracted-from-alsace.osm.pbf data/osm/bw-extracted-from-DACH.patched.osm.pbf
	$(info merging Baden-Württemberg extracts from Alsace & DACH)
	$(OSMIUM) merge -o $(TOOL_DATA)/$(@F) -O $(^F:%=$(TOOL_DATA)/%)

# pfaedle cannot parse OSM .pbf files yet, just XML
data/osm/%.osm: data/osm/%.osm.pbf
	$(info converting OSM .pbf to OSM XML for pfaedle)
	$(info see also https://github.com/ad-freiburg/pfaedle/issues/10)
	$(OSMIUM) cat $(TOOL_DATA)/$(<F) -o $(TOOL_DATA)/$(@F) -O


# For every merged dataset, it's composing feeds should be listed.
# At first, we define a variable with all feed names, which subsquently gets expanded
# to the complete paths
HBG = naldo.filtered VGC.filtered VVS.with_shapes.filtered
HBG_FILES = $(HBG:%=data/gtfs/%.gtfs.zip)
data/gtfs/hbg.merged.gtfs.zip: $(HBG_FILES)
	$(MERGE) $^ /$@

# Prepare second feed with SPNV added to test how it works
HBG2 = SPNV-BW.with_shapes naldo.filtered VGC.filtered VVS.with_shapes.filtered
HBG2_FILES = $(HBG2:%=data/gtfs/%.gtfs.zip)
data/gtfs/hbg2.merged.gtfs.zip: $(HBG2_FILES)
	$(MERGE) $^ /$@

ULM = SPNV-BW.with_shapes DING 
ULM_FILES = $(ULM:%=data/gtfs/%.gtfs.zip)
data/gtfs/ulm.merged.gtfs.zip: $(ULM_FILES)
	$(MERGE) $^ /$@

# Remove pre-existing filtered dir, to not accumulate shapes...
data/gtfs/%.filtered.gtfs.zip: data/gtfs/%.gtfs.zip data/gtfs-rules/%.rule
	rm -rf data/gtfs/$*.filtered.gtfs && $(TRANSFORM) --transform=/data/gtfs-rules/$*.rule /data/gtfs/$*.gtfs.zip /$@

# As we extract from DELFI and not only do patches, we check for the master file
# As target is a folder, we touch to explicitly set modified timestamp
data/gtfs/DELFI.%.filtered.gtfs: data/gtfs/DELFI.gtfs.zip data/gtfs-rules/DELFI.%.rule
	$(TRANSFORM) --transform=/data/gtfs-rules/DELFI.$*.rule /data/gtfs/DELFI.gtfs.zip /$@ && touch data/gtfs/DELFI.$*.filtered.gtfs/

# unzip filtered zip in case it is not yet (pfaedle requires feed unzipped). Before unzipping,rm all to avoid shape accumulation...
data/gtfs/%.filtered.gtfs: data/gtfs/%.filtered.gtfs.zip
	rm -rf data/gtfs/$*.filtered.gtfs && unzip -o -d data/gtfs/$*.filtered.gtfs data/gtfs/$*.filtered.gtfs 

# Apply pfaedle inplace and zip resulting files
data/gtfs/%.with_shapes.gtfs.zip: data/gtfs/%.filtered.gtfs
	$(PFAEDLE) --inplace -D -x /data/osm/bw-buffered.osm /data/gtfs/$*.filtered.gtfs && zip -j $@ data/gtfs/$*.filtered.gtfs/*.txt
