HOST_MOUNT = $(PWD)
TOOL_CFG = /cfg
TOOL_DATA = /data

TAIL = $(shell set +e; if [[ -x "$$(which gtail)" ]]; then echo gtail; else echo tail; fi)

.PHONY : all
.DELETE_ON_ERROR:
.PRECIOUS: data/osm/alsace.osm.pbf data/osm/DACH.osm.pbf data/osm/bw-buffered.osm.pbf data/osm/bw-buffered.osm

# To add a new merged feed, add it's shortname here and define the variable definitions and targets as for HBG below
MERGED = hbg hbg2 ulm
# To add a new filtered feed, add it's shortname below and add a DELFI.<shortname>.rule filter rule in config/gtfs-rules.
# NOTE: currently shape enhancement only is done using bw-buffered.osm
FILTERED = BW
all : $(MERGED:%=data/gtfs/%.merged.gtfs.zip) $(FILTERED:%=data/gtfs/DELFI.%.gtfs.zip) data/www/index.html

# Shortcuts for the (dockerized) transform/merge tools.
OSMIUM = docker run -i --rm -v $(HOST_MOUNT)/config/osm:$(TOOL_CFG) -v $(HOST_MOUNT)/data/osm:$(TOOL_DATA) mfdz/pyosmium osmium
OSMIUM_UPDATE = docker run -i --rm -v $(HOST_MOUNT)/data/osm:$(TOOL_DATA) mfdz/pyosmium pyosmium-up-to-date
OSMOSIS = docker run -i --rm -v $(HOST_MOUNT)/config/osm:$(TOOL_CFG) -v $(HOST_MOUNT)/data/osm:$(TOOL_DATA) mfdz/osmosis:0.47-1-gd370b8c4
TRANSFORM = docker run -i --rm -v $(HOST_MOUNT)/config/gtfs-rules:$(TOOL_CFG) -v $(HOST_MOUNT)/data/gtfs:$(TOOL_DATA) mfdz/otp-data-tools java -Xmx20g -jar one-busaway-gtfs-transformer/onebusaway-gtfs-transformer-cli.jar
PFAEDLE = docker run -i --rm -v $(HOST_MOUNT)/data/osm:$(TOOL_DATA)/osm -v $(HOST_MOUNT)/data/gtfs:$(TOOL_DATA)/gtfs mfdz/pfaedle
MERGE = docker run -v $(HOST_MOUNT)/data/gtfs:$(TOOL_DATA)/gtfs --rm mfdz/otp-data-tools java -Xmx18g -jar one-busaway-gtfs-merge/onebusaway-gtfs-merge-cli.jar --file=stops.txt --duplicateDetection=identity 
GTFSVTOR = docker run -i --rm -v $(HOST_MOUNT)/data/gtfs:$(TOOL_DATA)/gtfs -v $(HOST_MOUNT)/data/www:$(TOOL_DATA)/www -e GTFSVTOR_OPTS=-Xmx8G mfdz/gtfsvtor


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
HBG = naldo.filtered VGC.filtered VVS.with_shapes
HBG_FILES = $(HBG:%=data/gtfs/%.gtfs)
data/gtfs/hbg.merged.gtfs.zip: $(HBG_FILES)
	$(MERGE) $(^F:%=$(TOOL_DATA)/gtfs/%) $(TOOL_DATA)/gtfs/$(@F)

# Prepare second feed with SPNV added to test how it works
HBG2 = SPNV-BW.filtered naldo.filtered VGC.filtered VVS.with_shapes
HBG2_FILES = $(HBG2:%=data/gtfs/%.gtfs)
data/gtfs/hbg2.merged.gtfs.zip: $(HBG2_FILES)
	$(MERGE) $(^F:%=$(TOOL_DATA)/gtfs/%) $(TOOL_DATA)/gtfs/$(@F)

ULM = SPNV-BW.filtered DING.filtered
ULM_FILES = $(ULM:%=data/gtfs/%.gtfs)
data/gtfs/ulm.merged.gtfs.zip: $(ULM_FILES)
	$(MERGE) $(^F:%=$(TOOL_DATA)/gtfs/%) $(TOOL_DATA)/gtfs/$(@F)


# GTFS feeds: download, filtering, map-matching, validation

data/gtfs/%.raw.gtfs.zip:
	$(eval @_DOWNLOAD_URL := $(shell cat config/gtfs-feeds.csv | $(TAIL) -n +2 | awk -F';' '{if ($$1 == "$*") {print $$5}}'))
	if [ -z "${@_DOWNLOAD_URL}" ]; then 1>&2 echo 'missing entry in config/gtfs-feeds.csv'; exit 1; fi
	$(info downloading $* GTFS feed from ${@_DOWNLOAD_URL})
	./download.sh '${@_DOWNLOAD_URL}' '$@'

data/gtfs/%.filtered.gtfs: data/gtfs/%.raw.gtfs.zip config/gtfs-rules/%.rule
	$(info patching $* GTFS feed using OBA GTFS Transformer & config/gtfs-rules/$*.rule)
	$(TRANSFORM) --transform=$(TOOL_CFG)/$*.rule $(TOOL_DATA)/$*.raw.gtfs.zip $(TOOL_DATA)/$(@F)
	./patch_gtfs.sh "$*" "data/gtfs/$(@F)"
	touch $@

# TODO GTFS fixes should go into gtfs-rules or gtfs-feeds.csv
data/gtfs/%.filtered.gtfs: data/gtfs/%.raw.gtfs.zip
	$(info unzipping $* GTFS feed)
	rm -rf $@
	unzip -d $@ $<
	./patch_gtfs.sh "$*" "data/gtfs/$(@F)"
	touch $@

data/gtfs/%.with_shapes.gtfs: data/gtfs/%.filtered.gtfs data/osm/bw-buffered.osm
	$(eval @_MAP_MATCH_OSM := $(shell cat config/gtfs-feeds.csv | $(TAIL) -n +2 | awk -F';' '{if ($$1 == "$*") {print $$8}}'))
	$(info copying filtered $* GTFS feed into $@)
	rm -rf $@ && ./cp.sh -r data/gtfs/$*.filtered.gtfs $@
	$(info map-matching the $* GTFS feed using pfaedle)
	if [ "${@_MAP_MATCH_OSM}" != "Nein" ]; then $(PFAEDLE) --inplace -D -x $(TOOL_DATA)/osm/${@_MAP_MATCH_OSM} $(TOOL_DATA)/gtfs/$(@F); fi
	touch $@

data/gtfs/%.with_shapes.gtfs.zip: data/gtfs/%.with_shapes.gtfs
	$(info zipping the map-matched $* GTFS feed into $(@F))
	zip -j $@ $</*.txt

data/gtfs/%.gtfs.zip: data/gtfs/%.with_shapes.gtfs.zip
	$(info symlinking $(@F) -> $(<F))
	ln -f "$<" "$@"

data/www/gtfsvtor_%.html: data/gtfs/%.raw.gtfs.zip
	$(info running GTFSVTOR on the $* GTFS feed)
	2>/dev/null $(GTFSVTOR) -o $(TOOL_DATA)/www/$(@F) -p -l 1000 $(TOOL_DATA)/gtfs/$(<F) | $(TAIL) -1 >data/gtfs/$*.gtfsvtor.log

GTFS_FEEDS = $(shell cat config/gtfs-feeds.csv | $(TAIL) -n +2 | awk -F';' '{print $$1}' | tr '\n' ' ')
PROCESSED_GTFS_FEEDS = $(GTFS_FEEDS:%=data/gtfs/%.gtfs.zip)
GTFS_VALIDATION_RESULTS = $(GTFS_FEEDS:%=data/www/gtfsvtor_%.html)
data/www/index.html: $(PROCESSED_GTFS_FEEDS) $(GTFS_VALIDATION_RESULTS)
	$(info generating GTFS feed index from $(^F))
	./generate_gtfs_index.sh <config/gtfs-feeds.csv >data/www/index.html
