FROM       alpine
LABEL org.opencontainers.image.title="gtfs-hub"
LABEL org.opencontainers.image.description="Collecting, shape-enhancing, validating, fixing and (partially) merging GTFS feeds."
LABEL org.opencontainers.image.authors="MITFAHR|DE|ZENTRALE <hb@mfdz.de>"
LABEL org.opencontainers.image.documentation="https://github.com/mfdz/gtfs-hub"
LABEL org.opencontainers.image.source="https://github.com/mfdz/gtfs-hub"
LABEL org.opencontainers.image.licenses="GPL-3.0-only"

RUN apk add --update --no-cache \
  make \
  bash \
  wget \
  zip \
  docker-cli

WORKDIR /opt/gtfs-hub
VOLUME /var/data

ADD patch_gtfs.sh .
ADD download.sh .
ADD update_osm.sh .
ADD cp.sh .
ADD generate_gtfs_index.sh .
ADD makefile .

ADD config/ ./config/

CMD make all
