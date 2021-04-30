#!/bin/bash
set -e
set -o pipefail
set -x

export GTFS_DIR=$DATA_DIR/gtfs
export GTFS_SOURCES_CSV=./config/gtfs-feeds.csv
export REPORT_PUBLISH_DIR=$DATA_DIR/www/
export SUMMARY_FILE=$REPORT_PUBLISH_DIR/index.html


function download_and_check {
  export GTFS_FILE=$GTFS_DIR/$1.gtfs.zip
  local ERRORS=""
  local WARNINGS=""
  local ERROR_REGEX='^.* ([1-9][0-9]*) ERROR.*$'
  local WARNING_REGEX='^.* ([0-9]*) WARNING.*$'
  if [[ `cat $GTFS_DIR/$1.gtfsvtor.log` =~ $ERROR_REGEX ]]; then
    ERRORS=${BASH_REMATCH[1]}
  fi
  if [[ `cat $GTFS_DIR/$1.gtfsvtor.log` =~ $WARNING_REGEX ]]; then
    WARNINGS=${BASH_REMATCH[1]}
  fi

  echo "<tr>
          <td><a href='$4'>$1</a></td>
          <td>`date -r $GTFS_DIR/$1.gtfs.zip  +%Y-%m-%d`</td>
          <td>$5</td>
          <td>$6</td>
          <td><a href="$2">Download</a></td>
          <td><a href="gtfsvtor_$1.html">Report</a></td>
          <td class='errors'>$ERRORS</td>
          <td class='warnings'>$WARNINGS</td>
        </tr>" >> $SUMMARY_FILE
}

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
Ergebnisse der GTFSVTOR-Pr&uuml;fung mit dem <a href="https://github.com/mecatran/gtfsvtor">Mecatran GTFSVTOR</a> Validator von Laurent Grégoire aufgelistet.</p>
<p><b>HINWEIS</b>: Einige Verkehrsverb&uuml;nde ver&ouml;ffentlichen Datens&auml;tze derzeit unter einer versionsbezogenen URL. VBB und HVV rufen wir nicht automatisiert ab,
da Last-Modified/If-Modified-Since derzeit nicht unterst&uuml;tzt werden bzw. der Datensatz nicht unter eine permanten URL bereitgestellt wird.
F&uuml;r diese k&ouml;nnen wir nicht automatisch die aktuellste Version pr&uuml;fen und hier listen. Wir freuen uns &uuml;ber einen Hinweis, sollte es aktuellere Daten oder auch
weitere Datenquellen geben.</p>
<p>Feedback bitte an "hb at mfdz de"</p>
<table><tr>
  <th>Verbund</th>
  <th>Datum</th>
  <th>Lizenz</th>
  <th>Namensnennung</th>
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
