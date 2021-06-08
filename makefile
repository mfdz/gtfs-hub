HOST_MOUNT = $(shell set +e; if [[ -n "$$HOST_MOUNT" ]]; then echo "$$HOST_MOUNT"; else echo "$$PWD"; fi)
TOOL_CFG = /cfg
TOOL_DATA = /data

TAIL = $(shell set +e; if [[ -x "$$(which gtail)" ]]; then echo gtail; else echo tail; fi)

GTFS_FEEDS = $(shell cat config/gtfs-feeds.csv | $(TAIL) -n +2 | awk -F';' '{print $$1}' | tr '\n' ' ')
RAW_GTFS_FEEDS = $(GTFS_FEEDS:%=data/gtfs/%.raw.gtfs.zip)
GTFS_FEEDS_WITH_SHAPES = $(GTFS_FEEDS:%=data/gtfs/%.with_shapes.gtfs)
PROCESSED_GTFS_FEEDS = $(GTFS_FEEDS:%=data/gtfs/%.gtfs.zip)
GTFS_VALIDATION_RESULTS = $(GTFS_FEEDS:%=data/www/gtfsvtor_%.html)

.SUFFIXES:
.DEFAULT_TARGET: gtfs
.PHONY: osm gtfs .FORCE
.FORCE:
.PRECIOUS: data/osm/alsace.osm.pbf data/osm/DACH.osm.pbf data/osm/bw-buffered.osm.pbf data/osm/bw-buffered.osm
.SECONDARY:

osm: data/osm/bw-buffered.osm data/osm/bw-buffered.osm.pbf

# To add a new merged feed, add it's shortname here and define the variable definitions and targets as for HBG below
MERGED = hbg hbg2 hbg3 ulm
MERGED_WITH_FLEX = hbg3
# To add a new filtered feed, add it's shortname below and add a DELFI.<shortname>.rule filter rule in config/gtfs-rules.
# NOTE: currently shape enhancement only is done using bw-buffered.osm
FILTERED = BW
gtfs : $(MERGED:%=data/gtfs/%.merged.gtfs.zip) $(MERGED_WITH_FLEX:%=data/gtfs/%.merged.with_flex.gtfs.zip) $(FILTERED:%=data/gtfs/DELFI.%.gtfs.zip) data/www/index.html

# Shortcuts for the (dockerized) transform/merge tools.
OSMIUM = docker run -i --rm -v $(HOST_MOUNT)/config/osm:$(TOOL_CFG) -v $(HOST_MOUNT)/data/osm:$(TOOL_DATA) mfdz/pyosmium osmium
OSMIUM_UPDATE = docker run -i --rm -v $(HOST_MOUNT)/data/osm:$(TOOL_DATA) mfdz/pyosmium pyosmium-up-to-date
OSMOSIS = docker run -i --rm -v $(HOST_MOUNT)/config/osm:$(TOOL_CFG) -v $(HOST_MOUNT)/data/osm:$(TOOL_DATA) mfdz/osmosis:0.47-1-gd370b8c4
TRANSFORM = docker run -i --rm -v $(HOST_MOUNT)/config/gtfs-rules:$(TOOL_CFG) -v $(HOST_MOUNT)/data/gtfs:$(TOOL_DATA) mfdz/onebusaway-gtfs-modules java -Xmx20g -jar onebusaway-gtfs-transformer-cli.jar
PFAEDLE = docker run -i --rm -v $(HOST_MOUNT)/data/osm:$(TOOL_DATA)/osm -v $(HOST_MOUNT)/data/gtfs:$(TOOL_DATA)/gtfs adfreiburg/pfaedle
MERGE = docker run -v $(HOST_MOUNT)/data/gtfs:$(TOOL_DATA)/gtfs --rm mfdz/onebusaway-gtfs-modules java -Xmx18g -jar onebusaway-gtfs-merge-cli.jar --file=stops.txt --duplicateDetection=identity 
GTFSVTOR = docker run -i --rm -v $(HOST_MOUNT)/data/gtfs:$(TOOL_DATA)/gtfs -v $(HOST_MOUNT)/data/www:$(TOOL_DATA)/www -e GTFSVTOR_OPTS=-Xmx8G mfdz/gtfsvtor
GTFSTIDY = docker run -i --rm -v $(HOST_MOUNT)/data/gtfs:$(TOOL_DATA)/gtfs derhuerst/gtfstidy


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
	cp config/hbg.feed_info.txt /tmp/feed_info.txt
	zip -u -j $@ /tmp/feed_info.txt

# Prepare second feed with SPNV added to test how it works
HBG2 = SPNV-BW.filtered naldo.filtered VGC.filtered VVS.with_shapes
HBG2_FILES = $(HBG2:%=data/gtfs/%.gtfs)
data/gtfs/hbg2.merged.gtfs.zip: $(HBG2_FILES)
	$(MERGE) $(^F:%=$(TOOL_DATA)/gtfs/%) $(TOOL_DATA)/gtfs/$(@F)
	cp config/hbg.feed_info.txt /tmp/feed_info.txt
	zip -u -j $@ /tmp/feed_info.txt

HBG3 = naldo.filtered VGC.filtered VVS.with_shapes
HBG3_FILES = $(HBG3:%=data/gtfs/%.gtfs)
data/gtfs/hbg3.merged.gtfs.zip: $(HBG3_FILES)
	$(MERGE) $(^F:%=$(TOOL_DATA)/gtfs/%) $(TOOL_DATA)/gtfs/$(@F)
	cp config/hbg.feed_info.txt /tmp/feed_info.txt
	zip -u -j $@ /tmp/feed_info.txt

HBG4 = DELFI.BW-long-distance-S-TÜ-CW.with_shapes SPNV-BW.no-long-distance.with_shapes naldo.filtered VGC.filtered VVS.with_shapes
HBG4_FILES = $(HBG4:%=data/gtfs/%.gtfs)
data/gtfs/hbg4.merged.gtfs.zip: $(HBG4_FILES)
	$(MERGE) $(^F:%=$(TOOL_DATA)/gtfs/%) $(TOOL_DATA)/gtfs/$(@F)
	cp config/hbg.feed_info.txt /tmp/feed_info.txt
	zip -u -j $@ /tmp/feed_info.txt

data/gtfs/%.merged.with_flex.gtfs: data/gtfs/%.merged.gtfs.zip
	$(info unzipping $* GTFS feed)
	rm -rf $@
	unzip -d $@ $<
	$(info patching GTFS-Flex data into the GTFS feed)
	docker run -i --rm -v $(HOST_MOUNT)/data/gtfs/$(@F):/gtfs derhuerst/generate-herrenberg-gtfs-flex
data/gtfs/%.merged.with_flex.gtfs.zip: data/gtfs/%.merged.with_flex.gtfs
	rm -f $@
	zip -j $@ $</*.txt $</locations.geojson

ULM = SPNV-BW.filtered DING.filtered
ULM_FILES = $(ULM:%=data/gtfs/%.gtfs)
data/gtfs/ulm.merged.gtfs.zip: $(ULM_FILES)
	$(MERGE) $(^F:%=$(TOOL_DATA)/gtfs/%) $(TOOL_DATA)/gtfs/$(@F)
	cp config/ulm.feed_info.txt /tmp/feed_info.txt
	zip -u -j $@ /tmp/feed_info.txt


# GTFS feeds: download, filtering, map-matching, validation

data/gtfs/%.raw.gtfs.zip: .FORCE
	$(eval @_DOWNLOAD_URL := $(shell cat config/gtfs-feeds.csv | $(TAIL) -n +2 | awk -F';' '{if ($$1 == "$*") {print $$5}}'))
	if [ -z "${@_DOWNLOAD_URL}" ]; then 1>&2 echo 'missing entry in config/gtfs-feeds.csv'; exit 1; fi
	$(info downloading $* GTFS feed from ${@_DOWNLOAD_URL})
	./download.sh '${@_DOWNLOAD_URL}' '$@'
data/gtfs/%.raw.gtfs: data/gtfs/%.raw.gtfs.zip
	$(info unzipping $* GTFS feed)
	rm -rf $@
	unzip -d $@ $<
	./patch_raw_gtfs.sh "$*" "data/gtfs/$(@F)"
	touch $@

data/gtfs/%.filtered.gtfs: data/gtfs/%.raw.gtfs config/gtfs-rules/%.rule
	$(info patching $* GTFS feed using OBA GTFS Transformer & config/gtfs-rules/$*.rule)
	$(TRANSFORM) --transform=$(TOOL_CFG)/$*.rule $(TOOL_DATA)/$*.raw.gtfs $(TOOL_DATA)/$(@F)
	./patch_filtered_gtfs.sh "$*" "data/gtfs/$(@F)"
	touch $@

# special handling for DELFI.* & SPNV-BW.* feeds, because they all get generated from DELFI.raw.gtfs
data/gtfs/DELFI.%.filtered.gtfs: data/gtfs/DELFI.raw.gtfs config/gtfs-rules/DELFI.%.rule
	$(info patching DELFI.$* GTFS feed using OBA GTFS Transformer & config/gtfs-rules/DELFI.$*.rule)
	$(TRANSFORM) --transform=$(TOOL_CFG)/DELFI.$*.rule $(TOOL_DATA)/DELFI.raw.gtfs $(TOOL_DATA)/$(@F)
	./patch_filtered_gtfs.sh "DELFI.$*" "data/gtfs/$(@F)"
	touch $@
data/gtfs/SPNV-BW.%.filtered.gtfs: data/gtfs/SPNV-BW.raw.gtfs config/gtfs-rules/SPNV-BW.%.rule
	$(info patching SPNV-BW.$* GTFS feed using OBA GTFS Transformer & config/gtfs-rules/SPNV-BW.$*.rule)
	$(TRANSFORM) --transform=$(TOOL_CFG)/SPNV-BW.$*.rule $(TOOL_DATA)/SPNV-BW.raw.gtfs $(TOOL_DATA)/$(@F)
	./patch_filtered_gtfs.sh "SPNV-BW.$*" "data/gtfs/$(@F)"
	touch $@

# TODO GTFS fixes should go into gtfs-rules or gtfs-feeds.csv
data/gtfs/%.filtered.gtfs: data/gtfs/%.raw.gtfs
	$(info unzipping $* GTFS feed)
	rm -rf $@
	unzip -d $@ $<
	./patch_filtered_gtfs.sh "$*" "data/gtfs/$(@F)"
	touch $@

# create a filtered OSM dump, specifically for pfaedle
data/osm/%.osm.pfaedle: data/osm/%.osm data/gtfs/SPNV-BW.filtered.gtfs
	$(info converting OSM XML to pfaedle-filtered OSM XML)
	$(PFAEDLE) -x $(TOOL_DATA)/osm/$(<F) -i $(TOOL_DATA)/gtfs/SPNV-BW.filtered.gtfs -X $(TOOL_DATA)/osm/$(@F)
# use the filtered OSM for map matching
data/gtfs/%.with_shapes.gtfs: data/gtfs/%.filtered.gtfs | data/osm/bw-buffered.osm.pfaedle
	$(eval @_MAP_MATCH_OSM := $(shell cat config/gtfs-feeds.csv | $(TAIL) -n +2 | awk -F';' '{if ($$1 == "$*") {print $$8}}'))
	$(info copying filtered $* GTFS feed into $@)
	rm -rf $@ && ./cp.sh -r data/gtfs/$*.filtered.gtfs $@
	$(info map-matching the $* GTFS feed using pfaedle)
	if [ "${@_MAP_MATCH_OSM}" != "Nein" ]; then $(PFAEDLE) --inplace -D -x $(TOOL_DATA)/osm/bw-buffered.osm.pfaedle $(TOOL_DATA)/gtfs/$(@F) && $(GTFSTIDY) --remove-red-shapes -o $(TOOL_DATA)/gtfs/$(@F) $(TOOL_DATA)/gtfs/$(@F); fi
	touch $@

data/gtfs/%.with_shapes.gtfs.zip: data/gtfs/%.with_shapes.gtfs
	$(info zipping the map-matched $* GTFS feed into $(@F))
	zip -j $@ $</*.txt

data/gtfs/%.gtfs.zip: data/gtfs/%.with_shapes.gtfs.zip
	$(info symlinking $(@F) -> $(<F))
	ln -f "$<" "$@"

data/www/gtfsvtor_%.html: data/gtfs/%.raw.gtfs
	$(info running GTFSVTOR on the $* GTFS feed)
	2>/dev/null $(GTFSVTOR) -o $(TOOL_DATA)/www/$(@F) -p -l 1000 $(TOOL_DATA)/gtfs/$(<F) | $(TAIL) -1 >data/gtfs/$*.gtfsvtor.log

data/www/index.html: $(PROCESSED_GTFS_FEEDS) $(GTFS_VALIDATION_RESULTS)
	$(info generating GTFS feed index from $(^F))
	./generate_gtfs_index.sh <config/gtfs-feeds.csv >data/www/index.html
