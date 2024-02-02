FROM ubuntu
LABEL org.opencontainers.image.title="gtfs-hub"
LABEL org.opencontainers.image.description="Collecting, shape-enhancing, validating, fixing and (partially) merging GTFS feeds."
LABEL org.opencontainers.image.authors="MITFAHR|DE|ZENTRALE <hb@mfdz.de>"
LABEL org.opencontainers.image.documentation="https://github.com/mfdz/gtfs-hub"
LABEL org.opencontainers.image.source="https://github.com/mfdz/gtfs-hub"
LABEL org.opencontainers.image.licenses="GPL-3.0-only"

WORKDIR /gtfs-hub

RUN apt-get update && apt-get install -y \
    make \
    bash \
    moreutils \
    curl \
    zip \
    miller \
    ca-certificates \
    gnupg \
    lsb-release \
  && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
  && echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
  && apt-get update && apt-get install -y \
    docker-ce-cli \
  && apt-get clean

ADD scripts/ scripts/
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
