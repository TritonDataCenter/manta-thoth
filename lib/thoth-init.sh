#!/bin/bash
#
# Copyright 2020 Joyent, Inc.
#
# This initializes a `thoth debug` or `thoth analyze` instance. It runs either
# as a bash "initfile", or in the context of a Manta job.
#

thoth_fatal()
{
	echo thoth: "$*" 1>&2
	exit 1
}

thoth_onexit()
{
	[[ $1 -ne 0 ]] || exit 0
	thoth_fatal "error exit status $1"
}

#
# Unlike `thoth load` alone, this updates the index, the Manta file, and the
# local copy ./info.json.
#
thoth_load()
{
	local update=$1

	if [[ -f "$update" ]]; then
		local tmpfile=$THOTH_TMPDIR/thoth.out.$$

		cat $THOTH_INFO $update | json --deep-merge >$tmpfile
		mv $tmpfile $THOTH_INFO
	fi

	mput -qf $THOTH_INFO $THOTH_INFO_OBJECT
	$THOTH load $THOTH_INFO
}

#
# "sysprops" are those at the root, not under .properties
#
thoth_set_sys()
{
	local prop=$1
	local propfile=$THOTH_TMPDIR/thoth.prop.$$
	if [[ "$#" -lt 1 ]]; then
		thoth_fatal "failed to specify property"
	fi

	if [[ "$#" -eq 2 ]]; then
		local propval="$2"
	else
		local propval=`cat | sed 's/\\\\/\\\\\\\\/g' | \
		    sed 's/"/\\\\"/g' | sed ':a;N;$!ba;s/\\n/\\\\n/g'`
	fi

	echo "{ \"$prop\": \"$propval\" }" >$propfile
	thoth_load $propfile
}

thoth_set()
{
	local prop=$1
	local propfile=$THOTH_TMPDIR/thoth.prop.$$
	local propout=$THOTH_TMPDIR/thoth.out.$$
	if [[ "$#" -lt 1 ]]; then
		thoth_fatal "failed to specify property"
	fi

	if [[ "$#" -eq 2 ]]; then
		local propval="$2"
	else
		local propval=`cat | sed 's/\\\\/\\\\\\\\/g' | \
		    sed 's/"/\\\\"/g' | sed ':a;N;$!ba;s/\\n/\\\\n/g'`
	fi

	echo "{ \"properties\": { \"$prop\": \"$propval\" } }" >$propfile
	thoth_load $propfile
}

#
# "sysprops" are those at the root, not under .properties
#
thoth_unset_sys()
{
	local tmpfile=$THOTH_TMPDIR/thoth.out.$$

	if [[ "$#" -lt 1 ]]; then
		thoth_fatal "failed to specify property"
	fi

	cat $THOTH_INFO | json -e "this.$1=undefined" >$tmpfile
	mv $tmpfile $THOTH_INFO
	mput -qf $propout $THOTH_INFO_OBJECT
	$THOTH load $propout
}

thoth_unset()
{
	local tmpfile=$THOTH_TMPDIR/thoth.out.$$

	if [[ "$#" -lt 1 ]]; then
		thoth_fatal "failed to specify property"
	fi

	cat $THOTH_INFO | json -e "this.properties.$1=undefined" >$tmpfile
	mv $tmpfile $THOTH_INFO
	mput -qf $propout $THOTH_INFO_OBJECT
	$THOTH load $propout
}

thoth_ticket()
{
	thoth_set_sys ticket $*
}

thoth_unticket()
{
	thoth_unset_sys ticket
}

thoth_analyze()
{
	. $THOTH_ANALYZER
}

export THOTH_TMPDIR=$(pwd)
export THOTH_DUMP=$MANTA_INPUT_FILE
export THOTH_NAME=$(basename $(dirname $MANTA_INPUT_FILE))
export THOTH_INFO=$THOTH_TMPDIR/info.json
export THOTH_DIR=$(dirname $MANTA_INPUT_OBJECT)
export THOTH_INFO_OBJECT=$THOTH_DIR/info.json

#
# As `thoth load` only updates the index, it is the info of record, but we fall
# back to the Manta file if needed.
#
if [[ ! -f $THOTH_INFO ]]; then
	$THOTH info $THOTH_NAME >$THOTH_INFO 2>/dev/null ||
	    mget -q $THOTH_INFO_OBJECT >$THOTH_INFO 2>/dev/null
fi

export THOTH_TYPE=$(cat $THOTH_INFO | json type)

export PS1="thoth@$THOTH_NAME $ "
export DTRACE_DOF_INIT_DISABLE=1

# FIXME
#if [[ $(cat $THOTH_INFO | json cmd) == "node" ]]; then
#	FILE_STR="$(file $THOTH_DUMP)"
#	MDB_PROC=/usr/lib/mdb/proc
#	MDB_V8=mdb_v8_ia32.so
#	MDB_V8_DIR=/root/mdb
#	MDB_V8_LATEST=/Joyent_Dev/public/mdb_v8/latest
#	if [[ $FILE_STR == *"ELF 64-bit"* ]]; then
#		MDB_PROC=/usr/lib/mdb/proc/amd64
#		MDB_V8=mdb_v8_amd64.so
#		MDB_V8_DIR=/root/mdb/amd64
#	fi
#
#	if [[ ! -d $MDB_V8_DIR ]]; then
#		mkdir -p $MDB_V8_DIR
#	fi
#
#	if [[ ! -f $MDB_V8_DIR/v8.so ]]; then
#		MDB_V8_LATEST=`mget -q /Joyent_Dev/public/mdb_v8/latest`
#		mget -q $MDB_V8_LATEST/$MDB_V8 > $MDB_V8_DIR/v8.so
#	fi
#
#	if [[ ! -f ~/.mdbrc ]]; then
#		echo "::set -L $MDB_V8_DIR:$MDB_PROC" > ~/.mdbrc
#		echo "::load v8.so" >> ~/.mdbrc
#	fi

if [[ -n "$THOTH_ANALYZER_OBJECT" ]]; then
	export THOTH_ANALYZER=$THOTH_TMPDIR/$THOTH_ANALYZER_NAME
	mget -q $THOTH_ANALYZER_OBJECT >$THOTH_ANALYZER
else
	unset THOTH_ANALYZER
fi

# thoth analyze ...

if [[ "$THOTH_RUN_ANALYZER" = "true" ]]; then
	if [[ -n "$THOTH_ANALYZER_DCMD" ]]; then

		 #
		 # LIBPROC_INCORE_ELF=1 prevents us from loading whatever node
		 # binary happens to be in $PATH. This is necessary when
		 # debugging cores that do not match the bitness of the node
		 # binary found in $PATH.
		 #
		export LIBPROC_INCORE_ELF=1

		exec mdb -e "$THOTH_ANALYZER_DCMD" "$THOTH_DUMP"
	else
		thoth_analyze
	fi
	exit $?
fi

# thoth debug ...

if [[ -n "$THOTH_ANALYZER" ]]; then
	orig=$THOTH_ANALYZER.orig
	cp $THOTH_ANALYZER $orig

	echo "thoth: analyzer $THOTH_ANALYZER_NAME is in $THOTH_ANALYZER"
	echo "thoth: run \"thoth_analyze\" to run the analyzer"
	echo "thoth: any changes to \$THOTH_ANALYZER will be stored upon successful exit"

	# make sure thoth_*() are set
	declare -f >tmp.initfile.$$;

	if bash --init-file tmp.initfile.$$ -i; then
		if ! cmp $THOTH_ANALYZER $orig > /dev/null 2>&1; then
			echo "thoth: storing changes to \$THOTH_ANALYZER"
			mput -qf $THOTH_ANALYZER $THOTH_ANALYZER_OBJECT
			echo "thoth: done"
		fi
	fi

	exit $?
else
	 #
	 # LIBPROC_INCORE_ELF=1 prevents us from loading whatever node binary
	 # happens to be in $PATH. This is necessary when debugging cores that
	 # do not match the bitness of the node binary found in $PATH.
	 #
	export LIBPROC_INCORE_ELF=1

	exec mdb "$THOTH_DUMP"
fi
