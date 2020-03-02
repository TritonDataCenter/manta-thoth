#!/bin/bash
#
# Copyright 2020 Joyent, Inc.
#
# Remove dumps older than a certain cut-off period, for example,
# ones older than 180 days, only looking 14 days prior to that point:
#
# purge-thoth.sh -o 180 -w 14
#
# The JSON details are kept, and marked as 'purged'.
# Requires GNU date(1).
#

usage="purge-thoth.sh -o <days> -w <days>"
cutoff=
window=

set -o errexit
set -o pipefail

set -- `getopt o:w: $*`
if [ $? != 0 ]; then
	echo $usage
	exit 2
fi

for i in $*
do
case $i in
	-o) cutoff=$2; shift 2;;
	-w) window=$2; shift 2;;
esac
done

if [ $# -gt 1 ]; then
	echo $usage
	exit 2
fi

cutoff_mtime="$(date -d "$(date -u +%Y-%m-%d) - $cutoff days" +%s)"
thothcmd="thoth info mtime=$(( $cutoff + $window ))d"
tmpfile="$(mktemp)"

$thothcmd >$tmpfile 2>/dev/null
echo $tmpfile

json -ga name time ticket <$tmpfile | while read ln; do
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

	echo "Purging $name created $(date --date="@$time")"

	#
	# It's quicker to just try to purge again than to check if it's been
	# purged already.
	#

	#thoth set $name purged true
	#mrm -r $name || true
done

rm $tmpfile
exit 0
