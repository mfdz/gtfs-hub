
# To add a new merged feed, add it's shortname here and define the variable definitions and targets as for HBG below
MERGED = hbg ulm
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

data/gtfs/%.filtered.gtfs.zip: data/gtfs/%.gtfs.zip data/gtfs-rules/%.rule
	$(TRANSFORM) --transform=/data/gtfs-rules/$*.rule /data/gtfs/$*.gtfs.zip /$@

# As we extract from DELFI and not only do patches, we check for the master file
# As target is a folder, we touch to explicitly set modified timestamp
data/gtfs/DELFI.%.filtered.gtfs: data/gtfs/DELFI.gtfs.zip data/gtfs-rules/DELFI.%.rule
	$(TRANSFORM) --transform=/data/gtfs-rules/DELFI.$*.rule /data/gtfs/DELFI.gtfs.zip /$@ && touch data/gtfs/DELFI.$*.filtered.gtfs/

# unzip filtered zip in case it is not yet (pfaedle requires feed unzipped)...
data/gtfs/%.filtered.gtfs: data/gtfs/%.filtered.gtfs.zip
	unzip -o -d data/gtfs/$*.filtered.gtfs data/gtfs/$*.filtered.gtfs 

# Apply pfaedle inplace and zip resulting files
data/gtfs/%.with_shapes.gtfs.zip: data/gtfs/%.filtered.gtfs
	$(PFAEDLE) --inplace -D -x /data/osm/bw-buffered.osm /data/gtfs/$*.filtered.gtfs && zip -j $@ data/gtfs/$*.filtered.gtfs/*.txt
