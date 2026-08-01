#!/usr/bin/env bash

set -euo pipefail

curl -fsS --data-binary '@-' "http://localhost:9091/metrics/job/${1:?missing job name (1st arguement)}"
