FROM alpine
LABEL org.opencontainers.image.title="gtfs-hub"
LABEL org.opencontainers.image.description="Collecting, shape-enhancing, validating, fixing and (partially) merging GTFS feeds."
LABEL org.opencontainers.image.authors="MITFAHR|DE|ZENTRALE <hb@mfdz.de>"
LABEL org.opencontainers.image.documentation="https://github.com/mfdz/gtfs-hub"
LABEL org.opencontainers.image.source="https://github.com/mfdz/gtfs-hub"
LABEL org.opencontainers.image.licenses="GPL-3.0-only"

WORKDIR /gtfs-hub

RUN apk add --update --no-cache \
  make \
  bash \
  moreutils \
  curl \
  zip \
  docker-cli
# miller is not included in the main ("community" branch) package list yet.
# https://github.com/johnkerl/miller/issues/293#issuecomment-687661421
RUN apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing miller

ADD patch_raw_gtfs.sh patch_filtered_gtfs.sh ./
ADD download.sh .
ADD update_osm.sh .
ADD cp.sh .
ADD generate_gtfs_index.sh .
ADD makefile .

ADD config /gtfs-hub/config
VOLUME /gtfs-hub/config
VOLUME /gtfs-hub/data

ENV HOST_MOUNT=/gtfs-hub
ENTRYPOINT ["/usr/bin/make"]
CMD ["gtfs"]
