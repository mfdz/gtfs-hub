#!/bin/sh

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
  docker run --rm -v "$HOST_DATA":/data:rw mfdz/pfaedle --inplace -x /data/osm/bw-buffered.osm /data/gtfs/$1.gtfs
  # zip and move gtfs-out
  zip -j $GTFS_DIR/$1.with-shapes.gtfs.zip $GTFS_DIR/$1.gtfs/*.txt
  mv $GTFS_DIR/$1.with-shapes.gtfs.zip $REPORT_PUBLISH_DIR/gtfs
}

function download_and_check {
  export GTFS_FILE=$GTFS_DIR/$1.gtfs.zip
  echo Download $2
  downloadurl=$2
  if [ -f $GTFS_FILE ]; then
    # Check even non-permanent Urls, as link in CSV may have been changed
    if [ $1 != "VBB" -a $1 != "HVV"]; then
      response=$(curl -R -L -w "%{http_code}" -o $GTFS_FILE -z $GTFS_FILE $downloadurl)
    fi
  else
    response=$(curl -R -L -w "%{http_code}" -o $GTFS_FILE $downloadurl)
  fi

    case "$response" in
        200) docker run -t -v $HOST_DATA/gtfs:/gtfs mfdz/transitfeed feedvalidator_googletransit.py -o /gtfs/feedvalidator_$1.html -l 1000 -d /gtfs/$1.gtfs.zip 2>&1 | tail -1 > /$GTFS_DIR/$1.log
             if [ "$7" == "Ja" ]; then
               echo "Augment shapes for $1"
               augment_shapes $1 $OSM_FILE
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
  <li><a href='https://developers.google.com/transit/gtfs/reference/'>GTFS-Spezifikation</a></li>
  <li><a href='https://gtfs.org/best-practices/'>GTFS Best Practices</a></li>
  <li><a href='https://developers.google.com/transit/gtfs/reference/gtfs-extensions'>Google GTFS Extensions</a></li>
</ul>

</body></html>" >> $SUMMARY_FILE


cp $GTFS_DIR/*.html $REPORT_PUBLISH_DIR/
