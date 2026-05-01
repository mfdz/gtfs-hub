#!/bin/bash
set -e
set -o pipefail

export GTFS_DIR="$PWD/data/gtfs"

cat << EOF
<html><head>
<meta charset='utf-8'/>
<meta name='viewport' content='width=device-width, initial-scale=1.0, user-scalable=no'/>
<style>
table { border-collapse: collapse; }
table thead th, table tbody td { padding: .1em .2em; }
table thead tr:last-child th { border-bottom: 1px solid #222; }
table tbody tr:nth-child(odd) { background-color: #f0f0f0; }
.border-left { border-left: 1px solid #222; padding-left: .2em; }
.errors { text-align: right; color: rgb(255, 0, 0); }
.warnings { text-align: right; color: rgb(255, 120, 0) }
</style>
<title>GTFS-Publikationen</title></head>
<body><h1>GTFS-Publikationen</h1>
<p>Nachfolgend sind f&uuml;r die uns derzeit bekannten GTFS-Ver&ouml;ffentlichungen deutscher Verkehrsunternehmen und- verb&uuml;nde die Ergebnisse der GTFSVTOR-Prüfung mittels <a href="https://github.com/mecatran/gtfsvtor">GTFSVTOR</a> und <a href="https://github.com/MobilityData/gtfs-validator">GTFS Validator</a> aufgelistet.</p>
<p><b>HINWEIS</b>: Einige Verkehrsverb&uuml;nde ver&ouml;ffentlichen Datens&auml;tze derzeit unter einer versionsbezogenen URL. VBB und HVV rufen wir nicht automatisiert ab,
da Last-Modified/If-Modified-Since derzeit nicht unterst&uuml;tzt werden bzw. der Datensatz nicht unter eine permanten URL bereitgestellt wird.
F&uuml;r diese k&ouml;nnen wir nicht automatisch die aktuellste Version pr&uuml;fen und hier listen. Wir freuen uns &uuml;ber einen Hinweis, sollte es aktuellere Daten oder auch
weitere Datenquellen geben.</p>
<p>Feedback bitte an "hb at mfdz de"</p>
<table>
<thead>
<tr>
  <th colspan="5"></th>
  <th colspan="3" class="border-left">Validierung GTFSVTOR</th>
  <th colspan="3" class="border-left">Validierung GTFS Validator</th>
</tr>
<tr>
  <th>Verbund</th>
  <th>Datum</th>
  <th>Lizenz</th>
  <th>Namensnennung</th>
  <th>Download</th>
  <th class="border-left">Report</th>
  <th>Fehler</th>
  <th>Warnungen</th>
  <th class="border-left">Report</th>
  <th>Fehler</th>
  <th>Warnungen</th>
</tr>
</thead>
<tbody>
EOF

while IFS=';' read -r name lizenz nammensnennung permanent downloadurl infourl email addshapes
do
  if [ "$name" == "shortname" ]; then continue; fi

  GTFSVTOR_ERRORS=""
  GTFSVTOR_WARNINGS=""
  GTFSVTOR_ERROR_REGEX='^.* ([1-9][0-9]*) ERROR.*$'
  GTFSVTOR_WARNING_REGEX='^.* ([0-9]*) WARNING.*$'
  if [[ `cat $GTFS_DIR/$name.gtfsvtor.log` =~ $GTFSVTOR_ERROR_REGEX ]]; then
    GTFSVTOR_ERRORS=${BASH_REMATCH[1]}
  fi
  if [[ `cat $GTFS_DIR/$name.gtfsvtor.log` =~ $GTFSVTOR_WARNING_REGEX ]]; then
    GTFSVTOR_WARNINGS=${BASH_REMATCH[1]}
  fi

  gtfs_validator_report="$GTFS_DIR/$name.raw.gtfs.zip.gtfs-validator-result/report.json"
  GTFS_VALIDATOR_ERRORS="$(jq -rc 'add(.notices[] | select(.severity == "ERROR") | .totalNotices) // 0' "$gtfs_validator_report")"
  GTFS_VALIDATOR_WARNINGS="$(jq -rc 'add(.notices[] | select(.severity == "WARNING") | .totalNotices) // 0' "$gtfs_validator_report")"

  1>&2 echo "$name: $GTFSVTOR_ERRORS/$GTFS_VALIDATOR_ERRORS errors, $GTFSVTOR_WARNINGS/$GTFS_VALIDATOR_WARNINGS warnings"

  cat << EOF
  <tr>
          <td><a href='$infourl'>$name</a></td>
          <td>`date -r "$GTFS_DIR/$name.raw.gtfs.zip"  +%Y-%m-%d`</td>
          <td>$lizenz</td>
          <td>$nammensnennung</td>
          <td><a href="$downloadurl">Download</a></td>
          <td class="border-left"><a href="gtfsvtor_$name.html">Report</a></td>
          <td class='errors'>$GTFSVTOR_ERRORS</td>
          <td class='warnings'>$GTFSVTOR_WARNINGS</td>
          <td class="border-left"><a href="gtfs_validator_$name.html">Report</a></td>
          <td class='errors'>$GTFS_VALIDATOR_ERRORS</td>
          <td class='warnings'>$GTFS_VALIDATOR_WARNINGS</td>
        </tr>
EOF
done

cat << EOF
</tbody>
</table>

<p>Unter <a href='https://www.github.com/mfdz/GTFS-Issues'>github/mfdz/GTFS-Issues</a> sind weitere Probleme oder Erweiterungswünsche
dokumentiert.</p>
<p>Weitere Informationen:</p>
<ul>
  <li><a href='https://github.com/mfdz/gtfs-hub/'>GitHub-Repository dieser Seite</a></li>
  <li><a href='https://gtfs.org/documentation/schedule/reference/'>GTFS-Schedule-Spezifikation</a></li>
  <li><a href='https://gtfs.org/documentation/schedule/schedule-best-practices/'>GTFS Schedule Best Practices</a></li>
  <li><a href='https://developers.google.com/transit/gtfs/reference/gtfs-extensions'>Google GTFS Extensions</a></li>
</ul>

</body></html>
EOF
