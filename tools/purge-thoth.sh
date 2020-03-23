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
# Note that purged dumps remain in the index for posterity, but with
# properties.purged === "true".
#
# Requires GNU date(1).
#

usage="purge-thoth.sh -o <days> [-w <days>] [-d]"
cutoff=
dryrun=true
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
	-d) dryrun=false; shift 1;;
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
thothcmd="thoth info properties.purged=undefined otime=${cutoff}d"
if [[ "$window" -gt 0 ]]; then
	thothcmd="$thothcmd mtime=$(( $cutoff + $window ))d"
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

	if [[ "$cutoff_mtime" < "$time" ]]; then
		continue
	fi

	echo "Checking $name (created $(date --date="@$time"))"

	tmpfile2="$(mktemp)"

	if mget $path/info.json >$tmpfile2 2>/dev/null; then
		echo "Purging $name (created $(date --date="@$time"))"
		if [[ "$dryrun" = "false" ]]; then
			json -e 'properties.purged = "true"' <$tmpfile2 | \
			    thoth load /dev/stdin
			mrm -r $path
		fi
	elif thoth info $name >$tmpfile2; then
		# already deleted; mark as purged
		echo "marking $name as purged"
		json -e 'properties.purged = "true"' <$tmpfile2 | \
		    thoth load /dev/stdin
	fi

	rm $tmpfile2
done

rm $tmpfile
exit 0
