#!/bin/bash
#
# Copyright 2020 Joyent, Inc.
#
# Remove dumps older than a certain cut-off period, for example,
# ones older than 180 days, only looking 14 days prior to that point:
#
# purge-thoth.sh -o 180 -w 14 -d
#
# The -d option must be specified to actually remove anything (as this is a
# destructive action!).
#
# Note that purged dumps remain in the index (there's no facility to remove info
# from the thoth index currently).
#
# Requires GNU date(1).
#

usage="purge-thoth.sh -o <days> [-w <days>] [-d]"
cutoff=
purgecmd="mls"
window=0

set -o errexit
set -o pipefail

#
# Default GC sizes are far too small for our typical usage.
#
export NODE_OPTIONS="--max-old-space-size=8192"

set -- `getopt do:w: $*`
if [ $? != 0 ]; then
	echo $usage
	exit 2
fi

for i in $*
do
case $i in
	-d) purgecmd="mrm -r"; shift 1;;
	-o) cutoff=$2; shift 2;;
	-w) window=$2; shift 2;;
esac
done

if [[ -z "$cutoff" ]]; then
	echo $usage
	exit 2
fi

if [ $# -gt 1 ]; then
	echo $usage
	exit 2
fi

cutoff_mtime="$(date -d "$(date -u +%Y-%m-%d) - $cutoff days" +%s)"
if [[ "$window" -gt 0 ]]; then
	thothcmd="thoth info mtime=$(( $cutoff + $window ))d otime=${cutoff}d"
else
	thothcmd="thoth info otime=${cutoff}d"
fi

echo "$0: processing $thothcmd"
tmpfile="$(mktemp)"
$thothcmd >$tmpfile

#
# We'd love to use `json` here, but it can't handle the typical size of the
# output we get, even with the above GC tweak.  Good old `awk` will have to do.
#
awk -e '
BEGIN { name=""; time=""; ticket=""; }
/^        "name"/ {
	if (name != "") { print name " " time " " ticket; }
	gsub("\",*", "", $2);
	name=$2;
	time="";
	ticket="";
}
/^        "time"/ { gsub(",", "", $2); time=$2; }
/^        "ticket"/ { gsub("\2,*", "", $2); ticket=$2; }
END {
	if (name != "") { print name " " time " " ticket; }
}
' <$tmpfile | while read ln; do
	set -- $ln
	path=$1
	time=$2
	ticket=$3
	name=$(basename $path)

	if [[ -n "$ticket" ]]; then
		continue
	fi

	if [[ "$cutoff_time" < "$mtime" ]]; then
		continue
	fi

	if $purgecmd $path >/dev/null 2>&1; then
		echo "Purged $name (created $(date --date="@$time"))"
	fi
done

rm $tmpfile
exit 0
