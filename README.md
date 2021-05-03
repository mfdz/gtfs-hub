# GTFS-Hub

This project aims at providing community tested, probably quality/content enhanced, partially merged or filtered GTFS-feeds of (currently German) transport agencies.


## Motivation
Since April, 1st, 2020, DELFI e.V. provides a (75%) Germany wide GTFS feed. However, for some use cases only a regional subset is needed, or locally published feeds need to be merged to retain original trip_ids to match e.g. GTFS-RT feeds.

Additionally, the locally published datasets as well as the Germany-wide DELFI GTFS feed sometimes have quality issues or miss e.g. shape information.

While we hope, that all these problems are overcome soon, we currently still see a need to postprocess published data to overcome these shortcomings.

## Inner workings

### Updating, checking, enhancing GTFS
GTFS-Hub regularly checks on a list of well known GTFS-feeds for updates.

If they have been updated, they get

* downloaded, 
* quality checked via [Google's transitfeed feedvalidator](https://github.com/google/transitfeed) (exception is, for performance reasons, the DELFI GTFS feed)
* optionally enhanced with shapes using OSM data and the [pfaedle tool](https://github.com/ad-freiburg/pfaedle)
* optionally transformed with the [OneBusAway GTFS transformer tool](http://developer.onebusaway.org/modules/onebusaway-gtfs-modules/1.3.4-SNAPSHOT/onebusaway-gtfs-transformer-cli.html) (fed with a feed specific rule file)
* and optionally merged into larger aggregated GTFS feeds or filtered to a regional subset

### Updating and preparing OSM data
Before GFTS data is updated, the OSM data which is used to generate GFTFS shapes is updated.
To avoid daily downloading large pbf datasets (GTFS-Hub uses DACH (Germany, Austria, Switzerland) and Alsace (France)) 
from scratch, we only download the original datases once and update these afterwards via [`pyosmium-up-to-date`](https://docs.osmcode.org/pyosmium/latest/tools_uptodate.html) and prepares some 
region clipped extracts (namely Baden-Wuerttemberg including a buffer of some kilometers around the border).

As this extract will serve as input to [OpenTripPlanner](https://www.opentripplanner.org) as well, we do some additionally data processing on it to enhance some infos, e.g.

* For parkings close to stations with no `park_ride` tag yet, set `park_ride=yes`.
* Set some well-known parkings to [`park_ride=hov`](https://wiki.openstreetmap.org/wiki/Proposed_features/Tag:park_ride%3Dhov).

### Publishing
After updating OSM and GTFS data, you'll find the datasets in the folder `data/www`, ready to publish e.g. via a web serve serving this directory.

### External references
This project uses a couple of other Docker images:

* [mfdz/pfaedle](https://hub.docker.com/r/mfdz/pfaedle): a dockerized version of Patrick Brosi's tool pfaedle the enhance GTFS feeds by shapes map matched using OSM data
* [mfdz/pyosmium](https://hub.docker.com/r/mfdz/pyosmium): a dockerized version of (py)osmium to quickly update / cut / merge OSM data
* [mfdz/osmosis](https://hub.docker.com/r/mfdz/osmosis): a dockerized version of osmosis to enhance OSM data with a declarative instruction set
* [mfdz/transitfeed](https://hub.docker.com/r/mfdz/transitfeed): a dockerized version of google's transitfeed feedvalidator
* [mfdz/otp-data-tools](https://hub.docker.com/r/mfdz/otp-data-tools): a dockerized version of onebusaway's GTFS transform and merge tools

Thanks to everybody contributing to these tools, the OSM community and Geofabrik and the transit agencies providing the data download services.

## How to start gtfs-hub

### Prerequisites

You'll need to have Docker installed.

### Running GTFS-Hub
Start the download/transform process chain. Note the necessary HOST_DATA environment variable, which requires to be set to an absolute path to the data directory, as we use a Docker in Docker setup 
where data is shared via host-relative volumes.

```sh
docker run -e HOST_DATA=$(PWD)/data -v $(PWD)/data:/var/data -v /var/run/docker.sock:/var/run/docker.sock mfdz/gtfs-hub
```

If you want to use your own config instead, you may mount your own config directory, which

```sh
docker run -e HOST_DATA=$(PWD)/data -v $(PWD)/data:/var/data -v /var/run/docker.sock:/var/run/docker.sock -v $(PWD)/config:/opt/gtfs-hub/config mfdz/gtfs-hub
```

### Building the docker image
To build you own docker image, just do:

```sh
docker build -t mfdz/gtfs-hub .
```

