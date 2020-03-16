FROM       alpine
MAINTAINER MITFAHR|DE|ZENTRALE <hb@mfdz.de>

RUN apk add --update --no-cache \
  make \
  bash \
  curl \
  zip \
  && rm -rf /var/cache/apk/*

WORKDIR /opt/gtfs-hub

RUN curl -O https://download.docker.com/linux/static/stable/x86_64/docker-18.06.1-ce.tgz && \ 
  tar xzf docker-18.06.1-ce.tgz && \ 
  cp docker/docker /usr/bin/docker && \ 
  rm -rf docker*

VOLUME /var/data

ADD update_gtfs.sh .
ADD update_osm.sh .
ADD update_all.sh .
ADD makefile .

ADD config/ ./config/

CMD bash ./update_all.sh
