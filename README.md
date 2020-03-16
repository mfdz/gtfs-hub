# GTFS-Hub

This project aims at providing community tested, probably quality enhanced, partially merged GTFS-feeds of (currently) German transport agencies.

In contrast to a Germany-wide GTFS feed distributed via Delfi (the national access point), GTFS-hub collects and enhances feeds provided by local authorities.

## Motivation
Currently, the national access point provides timetable data in NeTEx format. Via [gtfs.de](http://gtfs.de) derived GTFS publications are available.

However, for upstreaming data to the national data access point seems not to be lossfree or  regularly. And there is no feedback channel to fix quality issues in a timely manner

While we hope, that all these problems are overcome soon, we currently still see a need to work with locally published GTFS data.

## Inner workings

### Updating, checking, enhancing GTFS
GTFS-Hub regularly checks on a list of well known GTFS-feeds, if the were updated.

If yes, they are 

* downloaded, 
* optionally enhanced with shapes using OSM data and the pfaedle tool
* quality checked via google's transitfeed feedvalidator
* optionally transformed with onebusaway transformer tool (fed with a feed specific rule file)
* and optionally merged into larger aggregated GTFS feeds

### Updating and preparing OSM data
Before GFTS data is updated, the OSM data which is used to generate GFTFS shapes is updated.
To avoid daily downloading large pbf datasets (GTFS-Hub downloads DACH (Germany, Austria, Switzerland) and Alsace (France)) from scratch, we only download the original datases once
and update these afterwards via pyosmium and prepares some region clipped extracts (namely Baden-Württemberg including a buffer of some kilometers around the border).

As this extract will serve as input to OpenTripPlanner as well, we do some additionally data processing on it to enhance some infos, e.g.

* Set some parkings to park_ride=yes for parkings close to stations but no park_ride tag yet
* Set some well known parkings to park_ride=hov 

### Publishing
After updating OSM and GTFS data, you'll find the datasets in data/www, ready to publish e.g. via a web serve serving this directory.

### External references
This project uses a couple of other dockerized applications:

* mfdz/pfaedle: a dockerized version of Patrick Brosi's tool pfaedle the enhance GTFS feeds by shapes map matched using OSM data
* mfdz/pyosmium: a dockerized version of (py)osmium to quickly update / cut / merge OSM data
* mfdz/osmosis: a dockerized version of osmosis to enhance OSM data with a declarative instruction set
* mfdz/transitfeed: a dockerized version of google's transitfeed feedvalidator
* mfdz/otp-data-tools: a dockerized version of onebusaway's GTFS transform and merge tools

Thanks to everybody contributing to these tools, the OSM community and Geofabrik and the transit agencies providing the data download services.

## How to start gtfs-hub

### Prerequisites

You'll need to have docker installed.

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

