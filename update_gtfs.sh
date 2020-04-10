#!/bin/bash

export DATA_DIR=/var/data
export GTFS_DIR=$DATA_DIR/gtfs
export GTFS_VALIDATED_DIR=$DATA_DIR/gtfs_validated
export GTFS_SOURCES_CSV=./config/gtfs-feeds.csv
export REPORT_PUBLISH_DIR=$DATA_DIR/www/
export SUMMARY_FILE=$GTFS_DIR/index.html


function augment_shapes {
  # extract gtfs
  # TODO GTFS fixes should go into gtfs-rules
  rm -rf "$GTFS_DIR/$1.gtfs"
  unzip -o -d $GTFS_DIR/$1.gtfs $GTFS_DIR/$1.gtfs.zip

  if [ "$1" == "VVS" ]; then
    # remove errornous transfers
    echo "Fixing VVS..."
    rm $GTFS_DIR/$1.gtfs/transfers.txt
  fi
  # call pfaedle
  docker run --rm -v "$HOST_DATA":/data:rw mfdz/pfaedle --inplace -x /data/osm/$2 /data/gtfs/$1.gtfs
  # zip and move gtfs-out
  zip -j $GTFS_DIR/$1.with-shapes.gtfs.zip $GTFS_DIR/$1.gtfs/*.txt
  mv $GTFS_DIR/$1.with-shapes.gtfs.zip $REPORT_PUBLISH_DIR/gtfs
}

function download_and_check {
  export GTFS_FILE=$GTFS_DIR/$1.gtfs.zip
  echo Download $2 to $GTFS_FILE
  downloadurl=$2
  if [ -f $GTFS_FILE ]; then
    echo "Checking update for $downloadurl"
    # if file already exists, we only want to download, if newer, hence we add -z flag to compare for file date
    # FIXME: Enabling this check performs a download, but does not set response_code (?)
    # if [[ $1 =~ ^(VBB|HVV)$ ]]; then
    # HVV and VBB dont send time stamps, so we ignore don't download them
    # TODO: we could store the url used for downloading and download, if it changed...
    response=$(curl -R -L -w '%{http_code}' -o $GTFS_FILE -z $GTFS_FILE $downloadurl)
    # fi
    #response=$(curl -R -L -w '%{http_code}' -o $GTFS_FILE -z $GTFS_FILE $downloadurl)
  else
    echo "First download"
    response=$(curl -R -L -w "%{http_code}" -o $GTFS_FILE $downloadurl)
  fi
  echo "Resulting http_code: $response"

    case "$response" in
        200) if [ "$1" != "DELFI" ]; then
               # DELFI is to large for current feedvalidator, takes multiple hours, have to dig into
               docker run -t -v $HOST_DATA/gtfs:/gtfs mfdz/transitfeed feedvalidator_googletransit.py -o /gtfs/feedvalidator_$1.html -l 1000 -d /gtfs/$1.gtfs.zip 2>&1 | tail -1 > /$GTFS_DIR/$1.log
             else
              # remove errornous transfers
              echo "Patching DELFI..."
              rm -rf "$GTFS_DIR/$1.gtfs"
              unzip -o -d $GTFS_DIR/$1.gtfs $GTFS_DIR/$1.gtfs.zip
              sed -i 's/"","Europe/"http:\/\/www.delfi.de\/","Europe/' $GTFS_DIR/$1.gtfs/agency.txt
              mv $GTFS_DIR/$1.gtfs/stops.txt $GTFS_DIR/$1.gtfs/stops.orig.txt && grep -v '\x08de:09372:2701:0:2' $GTFS_DIR/$1.gtfs/stops.orig.txt \
                 | grep -v '\x08de:09278:2840:0:1' | grep -v '\x08de:09278:641:0:1' | grep -v '\x08de:09278:645:0:1' > $GTFS_DIR/$1.gtfs/stops.txt
              sed -i 's/\x08//' $GTFS_DIR/$1.gtfs/stops.txt
              zip -j $GTFS_DIR/$1.gtfs.zip $GTFS_DIR/$1.gtfs/*
             fi
             if [ "$7" != "Nein" ]; then
               echo "Augment shapes for $1 using file $7"
               augment_shapes $1 $7
             fi
             ;;
        301) printf "Received: HTTP $response (file moved permanently) ==> $url\n" ;;
        304) printf "Received: HTTP $response (file unchanged) ==> $url\n" ;;
        404) printf "Received: HTTP $response (file not found) ==> $url\n" ;;
          *) printf "Received: HTTP $response ==> $url\n" ;;
  esac

  local ERRORS=""
  local WARNINGS=""
  local ERROR_REGEX='^.* ([0-9]*) error.*$'
  local WARNING_REGEX='^.* ([0-9]*) warning.*$'
  if [[ `cat $GTFS_DIR/$1.log` =~ $ERROR_REGEX ]]; then
    ERRORS=${BASH_REMATCH[1]}
  else
    cp -p $GTFS_FILE $GTFS_VALIDATED_DIR
  fi
  if [[ `cat $GTFS_DIR/$1.log` =~ $WARNING_REGEX ]]; then
    WARNINGS=${BASH_REMATCH[1]}
  fi

  echo "<tr>
          <td><a href='$4'>$1</a></td>
          <td>`date -r $GTFS_DIR/$1.gtfs.zip  +%Y-%m-%d`</td>
          <td>$5</td>
          <td>$6</td>
          <td><a href="$2">Download</a></td>
          <td><a href="feedvalidator_$1.html">Report</a></td>
          <td class='errors'>$ERRORS</td>
          <td class='warnings'>$WARNINGS</td>
        </tr>" >> $SUMMARY_FILE
}

mkdir -p $GTFS_DIR
mkdir -p $GTFS_VALIDATED_DIR
mkdir -p $REPORT_PUBLISH_DIR
echo "<html><head>
<meta charset='utf-8'/>
<meta name='viewport' content='width=device-width, initial-scale=1.0, user-scalable=no'/>
<style>
.errors { text-align: right; color: rgb(255, 0, 0); }
.warnings { text-align: right; color: rgb(255, 120, 0) }
</style>
<title>GTFS-Publikationen</title></head>
<body><h1>GTFS-Publikationen</h1>
<p>Nachfolgend sind f&uuml;r die uns derzeit bekannten GTFS-Ver&ouml;ffentlichungen deutscher Verkehrsunternehmen und- verb&uuml;nde die
Ergebnisse der feedvalidator-Pr&uuml;fung mit dem <a href="https://github.com/google/transitfeed">Google Transitfeed Feedvalidator</a> aufgelistet.</p>
<p><b>HINWEIS</b>: Einige Verkehrsverb&uuml;nde ver&ouml;ffentlichen Datens&auml;tze derzeit unter einer versionsbezogenen URL. VBB und HVV rufen wir nicht automatisiert ab,
da Last-Modified/If-Modified-Since derzeit nicht unterst&uuml;tzt werden bzw. der Datensatz nicht unter eine permanten URL bereitgestellt wird.
F&uuml;r diese k&ouml;nnen wir nicht automatisch die aktuellste Version pr&uuml;fen und hier listen. Wir freuen uns &uuml;ber einen Hinweis, sollte es aktuellere Daten oder auch
weitere Datenquellen geben.</p>
<p>Feedback bitte an "hb at mfdz de"</p>
<table><tr>
  <th>Verbund</th>
  <th>Datum</th>
  <th>Lizenz</th>
  <th>Nammensnennung</th>
  <th>Download</th>
  <th>Validierung</th>
  <th>Fehler</th>
  <th>Warnungen</th>
</tr>" > $SUMMARY_FILE



while IFS=';' read -r name lizenz nammensnennung permanent downloadurl infourl email addshapes
do
  if ! [ "$name" == "shortname" ]; then # ignore first line
    download_and_check $name $downloadurl $permanent $infourl "$lizenz" "$nammensnennung" "$addshapes"
  fi
done < $GTFS_SOURCES_CSV

echo "</table>

<p>Unter <a href='https://www.github.com/mfdz/GTFS-Issues'>github/mfdz/GTFS-Issues</a> sind weitere Probleme oder Erweiterungswünsche
dokumentiert.</p>
<p>Weitere Informationen:</p>
<ul>
  <li><a href='https://github.com/mfdz/gtfs-hub/'>GitHub-Repository dieser Seite</a></li>
  <li><a href='https://developers.google.com/transit/gtfs/reference/'>GTFS-Spezifikation</a></li>
  <li><a href='https://gtfs.org/best-practices/'>GTFS Best Practices</a></li>
  <li><a href='https://developers.google.com/transit/gtfs/reference/gtfs-extensions'>Google GTFS Extensions</a></li>
</ul>

</body></html>" >> $SUMMARY_FILE


cp $GTFS_DIR/*.html $REPORT_PUBLISH_DIR/
