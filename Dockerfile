FROM python:3.12
LABEL org.opencontainers.image.title="gtfs-hub"
LABEL org.opencontainers.image.description="Collecting, shape-enhancing, validating, fixing and (partially) merging GTFS feeds."
LABEL org.opencontainers.image.authors="MITFAHR|DE|ZENTRALE <hb@mfdz.de>"
LABEL org.opencontainers.image.documentation="https://github.com/mfdz/gtfs-hub"
LABEL org.opencontainers.image.source="https://github.com/mfdz/gtfs-hub"
LABEL org.opencontainers.image.licenses="GPL-3.0-only"

WORKDIR /gtfs-hub

RUN apt-get update && apt-get install -y \
    make \
    zip \
    miller \
    moreutils \
    ca-certificates \
    lsb-release \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
 && chmod a+r /etc/apt/keyrings/docker.gpg \
 && echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
   tee /etc/apt/sources.list.d/docker.list > /dev/null \
  && apt-get update && apt-get install -y \
    docker-ce-cli \
  && apt-get clean

ADD requirements.txt .
RUN pip install -r requirements.txt
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
