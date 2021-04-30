#!/bin/bash
set -e

1>&2 echo "trying to use copy-on-write (--reflink=auto/-c)"
2>/dev/null cp --reflink=auto $@ || 2>/dev/null cp -c $@ || cp $@
