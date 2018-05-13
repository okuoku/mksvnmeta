#!/bin/sh
seq $1 $2 | parallel --no-notice cmake -DREV={} $*
