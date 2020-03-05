#!/bin/bash
#
# Copyright 2020 Joyent, Inc.
#
# This initializes a local `thoth debug` or `thoth analyze run` instance.
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
	local tmpfile=$THOTH_TMPDIR/thoth.out.$$
	local infile=$1

	cat $THOTH_INFO $infile | json --deep-merge >$tmpfile
	mv $tmpfile $THOTH_INFO
	mput -qf $THOTH_INFO $THOTH_INFO_OBJECT
	thoth load $THOTH_INFO
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
	thoth load $propout
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
	thoth load $propout
}

thoth_ticket()
{
	thoth_set_sys ticket $*
}

thoth_unticket()
{
	thoth_unset_sys ticket
}

export THOTH_TMPDIR=$(pwd)
export THOTH_SUPPORTS_JOBS=false
export THOTH_DUMP=$MANTA_INPUT_FILE
export THOTH_NAME=$(basename $(dirname $MANTA_INPUT_FILE))
export THOTH_INFO=$THOTH_TMPDIR/info.json
export THOTH_DIR=$(dirname $MANTA_INPUT_OBJECT)
export THOTH_INFO_OBJECT=$THOTH_DIR/info.json

#
# As `thoth load` only updates the index, it is the info of record, but we fall
# back to the Manta file if needed.
#
thoth info $THOTH_NAME >$THOTH_INFO 2>/dev/null ||
    mget -q $THOTH_INFO_OBJECT >$THOTH_INFO 2>/dev/null

export THOTH_TYPE=`cat $THOTH_INFO | json type`

export PS1="$THOTH_NAME@thoth $ "
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
		. $THOTH_ANALYZER
	fi
	exit $?
fi

# thoth debug ...

if [[ -n "$THOTH_ANALYZER" ]]; then
	# 'orig=/var/tmp/' + analyzer + '.orig\n';
	# 'mget ' + path + ' > $THOTH_ANALYZER 2> /dev/null\n';
	# 'if [[ $? -ne 0 ]]; then\n';
	# '	echo "thoth: ' + analyzer + ' not found"\n';
	# '	exit 1\n';
	# 'fi\n';
	# 'cp $THOTH_ANALYZER $orig\n';
	# 'chmod +x $THOTH_ANALYZER\n';

	# 'echo "thoth: analyzer \\"' + analyzer + '\\" is in ' +
	#	    '\\$THOTH_ANALYZER"\n';
	# 'echo "thoth: run \\\"thoth_analyze\\\" to run ' +
	#	    '\\$THOTH_ANALYZER"\n';
	# 'echo "thoth: any changes to \\$THOTH_ANALYZER will ' +
	#	    'be stored upon successful exit"\n';
	# 'echo "alias thoth_analyze=\\\"' + analyze +
	#	    '\\\"" >> ~/.bashrc\n';
	# 'if ! bash -i; then\n';
	# '	exit $?\n';
	# 'fi\n';
	# 'if cmp $THOTH_ANALYZER $orig > /dev/null 2>&1; then\n';
	# '	exit 0\n';
	# 'fi\n';
	# 'echo "thoth: storing changes to \\$THOTH_ANALYZER"\n';
	# 'mput -f $THOTH_ANALYZER ' + path + ' 2> /dev/null\n';
	# 'echo "thoth: done"\n';
	: # FIXME
else
	 #
	 # LIBPROC_INCORE_ELF=1 prevents us from loading whatever node binary
	 # happens to be in $PATH. This is necessary when debugging cores that
	 # do not match the bitness of the node binary found in $PATH.
	 #
	export LIBPROC_INCORE_ELF=1

	exec mdb "$THOTH_DUMP"
fi
