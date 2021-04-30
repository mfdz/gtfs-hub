#!/bin/bash
set -e
set -o pipefail
set -x

export DATA_DIR=/var/data

pushd .
cd /var
make data/www/index.html
popd
