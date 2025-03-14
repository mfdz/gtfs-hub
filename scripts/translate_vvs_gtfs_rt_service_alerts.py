import argparse
import requests
import signal
import sys
import time
import logging
import os
import tempfile
import shutil

from gtfs_realtime_translators.registry import TranslatorRegistry
from logging import handlers

logger = logging.getLogger(__name__)

HIGH_PRIO_ROUTES = [
"de:vvs:31751_:",
"de:vvs:31753_:",
"de:vvs:31770_:",
"de:vvs:31773_:",
"de:vvs:31780_:",
"de:vvs:31782_:",
"de:vvs:31783_:",
"de:vvs:31790_:",
"de:vvs:31791_:",
"de:vvs:31794_:",
"de:vvs:31794_:",
"de:vvs:34070_:",
"de:vvs:34077_:",
"de:naldo:53N80_:",
"de:vvs:50775_:",
"de:vvs:50773_:",
"de:vvs:50779_:",
"de:vvs:50780_:",
"de:vvs:50782_:",
"de:vvs:50783_:",
"de:vvs:50794_:",
"de:vvs:31X77_:",
"de:vvs:50773_:",
"de:vvs:31774_:",
"de:vvs:50775_:",
"de:vvs:50780_:",
"de:vvs:50775_:",
"de:vvs:10001_:",
"de:vvs:10011_:",
"de:vvs:11063_:",
"de:vvs:36063e:",
"de:vvs:12047_:",
"de:vvs:11014_:",
"de:vvs:11004_:",]

HIGH_PRIO_KEYWORDS = ['Herrenberg', 'Gäubahn', 'Ammertalbahn', 'Streik']

def interrupt_handler(signum, frame):
    sys.exit(0)

def atomic_write(destFile, content, mode='w+b'):
    with tempfile.NamedTemporaryFile(delete=False, mode=mode) as f:
        f.write(content)
        # make sure that all data is on disk
        # see http://stackoverflow.com/questions/7433057/is-rename-without-fsync-safe
        f.flush()
        os.fsync(f.fileno()) 
        os.chmod(f.name, 0o644)   
        shutil.move(f.name, destFile)  


def main(translator_id, source, gtfsfile, interval, out, textfile, logfile, user_agent):
    translator_args = {'gtfsfile': gtfsfile, 'high_prio_keywords': HIGH_PRIO_KEYWORDS, 'high_prio_route_ids': HIGH_PRIO_ROUTES, }
    request_headers = {'user-agent': user_agent}
    last_last_modified = None
    if logfile:
        handler = handlers.TimedRotatingFileHandler(logfile, when='midnight', backupCount=1)
        handler.setFormatter(logging.Formatter('%(asctime)s translate_vvs_gtfs_rt_service_alerts [%(process)d]: %(message)s', datefmt="%d-%m-%Y %H:%M:%S"))
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)

    while True:
        try:
            # if lastModified date of gtfs file changed (or the first time), we re-initialize
            current_last_modified = os.path.getmtime(gtfsfile)
            if last_last_modified != current_last_modified:
                translator_class = TranslatorRegistry.get(translator_id)
                translator = translator_class(**translator_args)
                last_last_modified = current_last_modified

            response = requests.get(source, stream=True, headers=request_headers)
            response.raw.decode_content = True

            feed = translator(response.content)
            if textfile:
                atomic_write(textfile, str(feed), mode='w+t')
            atomic_write(out, feed.SerializeToString())
        except Exception:
            logger.exception(f'Error translating {translator}')

        time.sleep(interval)

if __name__ == '__main__':
    signal.signal(signal.SIGINT, interrupt_handler)

    parser = argparse.ArgumentParser(
        prog='gtfs-realtime-translator',
        description='Translates realtime transit data sources to gtfs-rt',)
    parser.add_argument('translator', help='translator')
    parser.add_argument('-s', '--source', nargs='?', help='source url to retrieve data from')
    parser.add_argument('-g', '--gtfsfile', nargs='?', help='gtfs file to map data to')
    parser.add_argument('-i', '--interval', nargs='?', default=60)
    parser.add_argument('-o', '--out', required=True)
    parser.add_argument('-t', '--textfile', required=False)
    parser.add_argument('-l', '--logfile', required=False)
    parser.add_argument('-u', '--useragent', default="gtfs_realtime_translator (https://github.com/mfdz/gtfs_realtime_translator/)")
    
    args = parser.parse_args()
    main(args.translator, args.source, args.gtfsfile, args.interval, args.out, args.textfile, args.logfile, args.useragent)


# python3 translate_vvs_gtfs_rt_service_alerts.py -g 'data/gtfs/VVS.raw.gtfs.zip' -s 'https://gtfsr-servicealerts.vvs.de' -o vvs.alerts.pbf -t vvs.alerts.txt -l vvs.alerts.log de-vvs-alerts
