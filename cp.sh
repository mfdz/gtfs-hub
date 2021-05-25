#!/bin/bash
set -e

# try to use copy-on-write (--reflink=auto/-c), fall back to plain cp
2>/dev/null cp --reflink=auto $@ || 2>/dev/null cp -c $@ || cp $@
