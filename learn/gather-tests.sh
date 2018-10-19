#!/bin/sh

set -euf

if [ -n "$TEST_DATA" ]; then
    DIRECTORY=$TEST_DATA/images/
else
    DIRECTORY=./
fi

FILENAME=$DIRECTORY/tests-train-1.jsonl.gz
TEMPNAME=$(mktemp "$FILENAME.XXXXXX")

if [ -f $FILENAME ]; then
    INPUT=$FILENAME
else
    INPUT=/dev/null
fi

BASE=$(dirname "$0")
zcat -f "$INPUT" | "$BASE/data-github" --verbose "$@" | "$BASE/data-expand" --verbose | gzip > "$TEMPNAME"
mv -f "$TEMPNAME" "$FILENAME"
