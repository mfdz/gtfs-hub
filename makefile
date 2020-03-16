
ALL = hbg bw
all : $(ALL:%=data/gtfs_validated/%.merged.gtfs.zip)
.PHONY : all

# https://www.gnu.org/software/make/manual/html_node/Automatic-Variables.html

# Shortcuts for the (dockerized) transform/merge tools. 
MERGE = docker run -v $(HOST_DATA):/data --rm mfdz/otp-data-tools java -Xmx14g -jar one-busaway-gtfs-merge/onebusaway-gtfs-merge-cli.jar --file=stops.txt --duplicateDetection=identity 
TRANSFORM = docker run -v $(HOST_DATA):/data --rm mfdz/otp-data-tools java -Xmx6g -jar one-busaway-gtfs-transformer/onebusaway-gtfs-transformer-cli.jar 

# For every merged dataset, it's composing feeds should be listed.
# At first, we define a variable with all feed names, which subsquently gets expanded
# to the complete paths
HBG = SPNV-BW naldo.filtered VGC.filtered VVS.filtered
HBG_FILES = $(HBG:%=data/gtfs_validated/%.gtfs.zip)

# For BW we build upon the already merged Hbg feed and all missing agencies
BW = VAGFR bodo DING Filsland HNV HVG KVSH KVV OstalbMobil RAB Rexer RVS SBG SWEG SWHN TGO TUTicket VGF.filtered VPE VRN SPNV-BW naldo.filtered VGC.filtered VVS.filtered
BW_FILES = $(BW:%=data/gtfs_validated/%.gtfs.zip)

data/gtfs/hbg.merged.gtfs.zip: $(HBG_FILES)
	$(MERGE) $^ /$@

data/gtfs/bw.merged.gtfs.zip: $(BW_FILES)
	$(MERGE) $^ /$@

data/gtfs_validated/%.filtered.gtfs.zip: data/gtfs_validated/%.gtfs.zip data/gtfs-rules/%.rule
	$(TRANSFORM) --transform=/data/gtfs-rules/$*.rule /data/gtfs/$*.gtfs.zip /$@
