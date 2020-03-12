manta-thoth
===========

Thoth is a Manta-based system for core and crash dump management for
illumos-derived systems like SmartOS, OmniOS, DelphixOS, Nexenta, etc. --
though in principle it can operate on any system that generates ELF
core files.

# Installation

    $ npm install git://github.com/joyent/manta-thoth.git#master

# Setup

As with the [node-manta](https://github.com/joyent/node-manta) CLI tools,
you will need to set Manta environment variables that match your Manta account:

    $ export MANTA_KEY_ID=`ssh-keygen -l -f ~/.ssh/id_rsa.pub | awk '{print $2}' | tr -d '\n'`
    $ export MANTA_URL=https://us-east.manta.joyent.com
    $ export MANTA_USER=bcantrill

You may also need to set your `THOTH_USER` environment variable if you are using
a shared Thoth installation. For example, if your shared Thoth installation
uses the 'thoth' Manta user:

    $ export THOTH_USER=thoth

If `$THOTH_USER` is set, `$MANTA_USER` must have read and write access
to `/$THOTH_USER/stor/thoth`.

While all of its canonical data resides in Manta, Thoth uses
[RethinkDB](https://www.rethinkdb.com) for metadata caching.
If setting up  a new `$THOTH_USER`,
[RethinkDB should be installed](https://www.rethinkdb.com/docs/install/)
on a server, and then pointed to via `$THOTH_USER/stor/thoth/config.json`
as described below.

Once RethinkDB is installed, the `authKey` should be set.
On versions of RethinkDB of 2.3 or more recent, this can be done via the
Data Explorer from the RethinkDB web interface:

    r.db('rethinkdb').table('users').get('admin').update({password:'I<3dumps!'})

(Once this has been done, it's wise to disable web administration by
uncommenting the `no-http-admin` line in the RethinkDB instances's configuration file.)

To initialize thoth, first store the RethinkDB credentials in Manta at
`$THOTH_USER/stor/thoth/config.json`:

    {
            "db": { "host": "my-thoth-server", "authKey": "I<3dumps!" }
    }

Then, run `thoth init`:

    $ thoth init
    thoth: using database at my-thoth-server:28015 (configured from Manta)
    thoth: created database 'bcantrill'
    thoth: created table 'dumps'
    thoth: created table 'analyzers'
    thoth: created index 'time'

Now you can upload your first core dump:

    $ thoth upload ./core.bc.24388
    thoth: using database at my-thoth-server:28015 (configured from Manta)
    thoth: creating 76998f82a450a8914037e4da838ec609
    thoth: uploading core.bc.24388 to 76998f82a450a8914037e4da838ec609
    thoth: core.bc.24388 [=======================>] 100%   3.83MB
    thoth: creating job to uncompress 76998f82a450a8914037e4da838ec609
    thoth: adding key to job 42b9feff-56d5-482a-b12b-da2099fd44ed
    thoth: processing job 42b9feff-56d5-482a-b12b-da2099fd44ed
    thoth: waiting for completion of job 42b9feff-56d5-482a-b12b-da2099fd44ed
    thoth: job 42b9feff-56d5-482a-b12b-da2099fd44ed completed in 0h0m14s
    thoth: creating job to process 76998f82a450a8914037e4da838ec609
    thoth: adding key to job 3e434caf-0544-6e89-ed71-8fa1630adcde
    thoth: processing 76998f82a450a8914037e4da838ec609
    thoth: waiting for completion of job 3e434caf-0544-6e89-ed71-8fa1630adcde
    thoth: job 3e434caf-0544-6e89-ed71-8fa1630adcde completed in 0h0m8s

This dump should appear in `thoth ls` output:

    $ thoth ls
    thoth: using database at my-thoth-server:28015 (configured from Manta)
    NAME             TYPE  TIME                NODE/CMD         TICKET
    76998f82a450a891 core  2015-12-04T13:10:26 bc               -

# Running Thoth

## Introduction

Thoth consists primarily of the `thoth` utility, a veneer on Manta that
generates a _hash_ unique to a core or crash dump, uploads that dump to a
directory under `$MANTA_USER/stor/thoth`, loads the metadata associated
with the dump into a RethinkDB-based querying database, and offers facilities
to list, filter and (most importantly) debug those dumps.

If used with a Manta v1 installation, `thoth` uses Manta jobs. With Manta v2,
jobs are not supported. In this case, things such as `thoth debug` run on the
local machine.

### Dump specifications

Most `thoth` subcommands operate on a _dump specification_: a dump's hash
(or substring thereof) or a space-delimited set of constraints based on its
properties.  A constraint consists of a property name, a single equals sign,
and the value (or globbed expression) to match.  For example, to list all
crash dumps from the node 95SY9R1:

    $ thoth ls type=crash node=95SY9R1

#### Special token: `mtime`

The special token `mtime` denotes how long ago the dump was uploaded,
with equality denoting recency.  For example, to list all of the dumps
uploaded in the last 6 hours:

    $ thoth ls mtime=6h
    thoth: using database at thoth-db:28015 (configured from Manta)
    NAME             TYPE  TIME                NODE/CMD         TICKET
    e1f5422b892d9394 core  2017-11-17T19:34:29 java             -
    c04110bc8190a84e core  2017-11-17T19:39:52 node             -
    b9379570b4a9a224 core  2017-11-17T19:39:52 node             -
    5f1171019ce419cb core  2017-11-17T19:51:01 node             -
    713f9e8b48559acd core  2017-11-17T19:55:57 node             -
    d91719939666de40 core  2017-11-17T20:05:57 node             -
    beaa65d3548ac96f core  2017-11-17T20:23:19 pg_prefaulter    -
    5841ba86a2b198be core  2017-11-17T20:53:06 node             -
    3d8921ce583dff68 core  2017-11-17T20:54:06 node             -
    34a8661c049456b1 core  2017-11-17T21:14:09 node             -
    6d75f1cd30898f48 core  2017-11-17T21:31:19 node             -
    cc2328f7d8a6c4ad core  2017-11-17T21:41:15 node             -
    b0b6f4ed9ab418ce core  2017-11-17T21:51:20 node             -
    5d64e695505d15c9 core  2017-11-17T22:11:18 node             -
    96d2271d81e4cd63 core  2017-11-17T22:21:17 node             -
    71aff9c315553b03 core  2017-11-17T23:31:14 node             -
    72f18495c7f54841 core  2017-11-18T00:21:17 node             -

#### Special token: `limit`

The special token `limit` denotes that the number of dumps specified
should be limited to the parameter, allowing a smaller number of
dumps to be examined.  (Exactly which dumps will be returned is unspecified.)
For example, to get the ID of at most five dumps from commands that begin with
"system":

    $ thoth info cmd=systemd* limit=5 | json -ga id
    thoth: using database at thoth-db:28015 (configured from Manta)
    00103a107b5db8f79ebc77782b707d07
    0071f6c50b39f1a917ba21a957f43e3f
    0021e9c447815c1f7a91e1af2672543b
    00d7ae803e01365798654c4dbeea5b28
    012c3f942d0b7de6b7dbc8eed8798b86

#### Special token: `undefined`

The special token `undefined` denotes a property that isn't set.  For
example, to list all dumps that were added in the last one hundred days that
begin with `svc` that don't have a ticket:

    $ thoth ls mtime=100d cmd=svc* ticket=undefined
    thoth: using database at thoth-db:28015 (configured from Manta)
    NAME             TYPE  TIME                NODE/CMD         TICKET
    0ecc8338c5949ea7 core  2017-08-10T01:57:56 svc.startd       -
    925de938d529e58b core  2017-08-18T03:51:27 svcs             -
    1d16db174473d8b5 core  2017-08-18T04:53:30 svcs             -
    2b4b3f5931e4b945 core  2017-08-18T05:39:14 svcs             -
    c5761bf75ea51a3f core  2017-08-18T08:27:01 svcs             -
    2204949c1735126b core  2017-08-18T15:08:35 svcs             -
    bc987a441a10da48 core  2017-08-24T17:44:41 svc.startd       -
    d7ba3510178394c3 core  2017-09-06T12:53:45 svcs             -
    48157650dc2d4204 core  2017-09-07T00:24:59 svccfg           -
    c48278b2930f991c core  2017-09-07T01:09:49 svccfg           -
    14918d63fb7239da core  2017-09-26T01:26:44 svc.startd       -
    9a29ead38c89930a core  2017-10-01T08:22:37 svc.configd      -
    d36a11c974f7f03d core  2017-10-01T08:22:37 svc.startd       -
    463412ce271ec7ec core  2017-10-02T15:39:23 svc.startd       -

#### Special specification: `dump=stdin`

The special specification `dump=stdin` denotes that dump identifiers should
be read from standard input, e.g.:

    $ cat /tmp/dumps
    3f7a8bde5a907afab7f966b9963c7d10
    3260a5e49918260ccdc1f94830c937c1
    f12ea8712e8b2586f062b03808b1c292
    5aaa91149e94a91f66c76b00ec1de521
    04a681f27ffcd19952d8efb75006c490
    $ cat /tmp/dumps | thoth ls dump=stdin
    thoth: using database at thoth-db:28015 (configured from Manta)
    thoth: reading dump identifiers from stdin
    NAME             TYPE  TIME                NODE/CMD         TICKET
    3260a5e49918260c core  2017-11-16T22:30:22 pg_prefaulter    -
    5aaa91149e94a91f core  2017-11-17T11:07:43 pg_prefaulter    -
    04a681f27ffcd199 core  2017-11-17T14:12:27 pg_prefaulter    -
    3f7a8bde5a907afa core  2017-11-17T14:42:03 pg_prefaulter    -
    f12ea8712e8b2586 core  2017-11-17T17:22:21 pg_prefaulter    -

## Subcommands

`thoth` operates by specifying a subcommand.  Many subcommands kick
off Manta jobs when using v1, and the job ID is presented in the command line
(allowing Manta tools like [`mjob`](https://github.com/joyent/node-manta/blob/master/docs/man/mjob.md) to be used to observe or debug behavior).
In general, success is denoted by an exit status 0 and failure by an
exit status of 1 -- but some subcommands can exit with other status
codes (notably, `info`).  The following subcommands are supported:

### upload

Takes the name of a core or crash dump to upload.  It will generate a
hash unique to the dump, upload the dump, and kick off a Manta job to
postprocess it:

    $ thoth upload core.19972
    thoth: creating 3e166b93871e7747c799008f58bd30b9
    thoth: uploading core.19972 to 3e166b93871e7747c799008f58bd30b9
    thoth: core.19972    [=======================>] 100%   1.94MB
    thoth: creating job to uncompress 3e166b93871e7747c799008f58bd30b9
    thoth: adding key to job 84b7f163-ecda-49bd-ba8e-ffc5efd8da62
    thoth: processing job 84b7f163-ecda-49bd-ba8e-ffc5efd8da62
    thoth: waiting for completion of job 84b7f163-ecda-49bd-ba8e-ffc5efd8da62
    thoth: job 84b7f163-ecda-49bd-ba8e-ffc5efd8da62 completed in 0h0m4s
    thoth: creating job to process 3e166b93871e7747c799008f58bd30b9
    thoth: adding key to job da3c0bf5-b04f-445b-aee7-af43ea3d17c0
    thoth: processing 3e166b93871e7747c799008f58bd30b9
    thoth: waiting for completion of job da3c0bf5-b04f-445b-aee7-af43ea3d17c0
    thoth: job da3c0bf5-b04f-445b-aee7-af43ea3d17c0 completed in 0h0m2s

If using Manta v2, a kernel crash dump is not uncompressed after uploading (and
only minimal information is collected in `thoth info` for the dump). The
analyzer `process-dump` can be used to do this post-upload.

### info

Returns the JSON blob associated with the specified dump.

    $ thoth info 3e166b93871e7747c799008f58bd30b9
    {
    	"name": "/bcantrill/stor/thoth/3e166b93871e7747c799008f58bd30b9",
    	"dump": "/bcantrill/stor/thoth/3e166b93871e7747c799008f58bd30b9/core.19972",
    	"pid": "19972",
    	"cmd": "utmpd",
    	"psargs": "/usr/lib/utmpd",
    	"platform": "joyent_20130418T192128Z",
    	"node": "headnode",
    	"version": "1",
    	"time": 1366869350,
    	"stack": [ "libc.so.1`__pollsys+0x15()", "libc.so.1`poll+0x66()", "wait_for_pids+0xe3()", "main+0x379()", "_start+0x83()" ],
    	"type": "core",
    	"properties": {}
    }

[Trent Mick](https://github.com/trentm)'s excellent
[json](https://github.com/trentm/json) is recommended to post-process these
blobs; here's an example of printing out the stack traces of dumps that match
a particular ticket:

    $ thoth info ticket=OS-2359 | json -ga dump stack
    thoth: created job 8ba4fae1-ce47-43fa-af24-3ad2916d48f1
    thoth: waiting for completion of job 8ba4fae1-ce47-43fa-af24-3ad2916d48f1
    thoth: job 8ba4fae1-ce47-43fa-af24-3ad2916d48f1 completed in 0h0m19s
    /thoth/stor/thoth/baef9f79a473580347b6338574007953/core.svc.startd.23308 [
      "libc.so.1`_lwp_kill+0x15()",
      "libc.so.1`raise+0x2b()",
      "libc.so.1`abort+0x10e()",
      "utmpx_postfork+0x44()",
      "fork_common+0x186()",
      "fork_configd+0x8d()",
      "fork_configd_thread+0x2ca()",
      "libc.so.1`_thrp_setup+0x88()",
      "libc.so.1`_lwp_start()"
    ]
    /thoth/stor/thoth/ba137fd783fd3ffb725fe8d70b3bb62f/core.svc.startd.27733 [
      "libc.so.1`_lwp_kill+0x15()",
      "libc.so.1`raise+0x2b()",
      "libc.so.1`abort+0x10e()",
      "utmpx_postfork+0x44()",
      "fork_common+0x186()",
      "fork_configd+0x8d()",
      "fork_configd_thread+0x2ca()",
      "libc.so.1`_thrp_setup+0x88()",
      "libc.so.1`_lwp_start()"
    ]
    ...

Note that for the `info` subcommand, a dump specification can also consist
of a local dump -- in which case the hash of that dump will be determined
locally, and the corresponding dump information will be retrieved (if it
exists).  This is a useful way of determining if a dump has already been
uploaded to thoth: an exit status of 0 denotes that the information was found;
an exit status of 2 denotes that the dump was not found.

    $ thoth info core.that.i.already.uploaded > /dev/null ; echo $?
    0
    $ thoth info core.that.i.have.never.seen.before > /dev/null ; echo $?
    2

### debug

Results in an interactive debugging session debugging the specified dump.

If using Manta v2, the dump is downloaded locally into `/var/tmp/thoth/cache`.
It is not deleted, so running again will be much quicker; a simple `rm` is
sufficient to clean up any unwanted local dumps.

### ls

Lists the dumps that match the dump specification, or all dumps if no
dump specification is provided.  By default, the dumps are listed in time
order from oldest to newest.

A dump abbreviation, the dump type, the time, the node or command, and the
ticket are provided for each dump -- but `ls` will additionally display
any property provided.  For example, to list the stack trace in addition for
all dumps in the last three days from the `pg_prefaulter` command:

    $ thoth ls mtime=3d cmd=pg_prefaulter stack

### object

For a given local dump, provides the hashed name of the object.

    $ thoth object core.19972
    3e166b93871e7747c799008f58bd30b9

This can be used to automate uploads of dumps.

### report

Gives a JSON report of the given property across the given dump specification.
For example, here's a report of `platform` for cores from the
command `svc.startd`:

    $ thoth report cmd=svc.startd platform
    {
      "joyent_20130625T221319Z": 47,
      "joyent_20130613T200352Z": 57
    }

### set

Sets a user property, which will appear in the `properties` field of the
JSON blob retrieved via `info`.  The value for the property can be
a string:

    $ thoth set 086d664357716ae7 triage bmc
    $ thoth info 086d664357716ae7 | json properties.triage
    bmc

Or specified as a JSON object via stdin:

    $ thoth set cmd=svc.configd triage <<EOF
    {
        "category": "SMF",
        "engineer": "bmc"
    }
    EOF
    $ thoth info 086d664357716ae7 | json properties.triage.engineer
    bmc

### unset

Unsets a user property.  Once a property is unset, it can be searched for
in a dump specification by using the special token `undefined`.

### ticket

Sets a ticket on a dump, a field of arbitrary alphanumeric characters
purely for being able to associate the dump with a defect tracking system.

### unticket

Unsets a ticket on a dump.

### analyze

On the specified dumps, runs the specified analyzer, as uploaded via the
`analyzer` subcommand.  An analyzer is a shell script that runs against a given
dump.  The following shell variables are made available in the context of an
analyzer:

* `$THOTH_DUMP`: The path of the dump.  (This is set to the same
  value as `$MANTA_INPUT_FILE`.)

* `$THOTH_INFO`: The path of a local file that contains the JSON
  info for the dump. The [json](https://github.com/trentm/json) utility
  may be used to parse this file.

* `$THOTH_TYPE`: The type of the dump (either `crash` or `core`).

* `$THOTH_NAME`: The full name (that is, hash) of the dump.

* `thoth_set`: A shell function that will set the specified property
  to the specified value or, if no value is specified, standard input.

* `thoth_unset`: A shell function that will unset the specified property
  on the dump being analyzed.

* `thoth_ticket`: A shell function that will set the ticket on the
  dump being analyzed to the ticket specified.

* `thoth_unticket`: A shell function that will unset the ticket on the
  dump being analyzed.

For example, here is an analyzer that looks for a particular stack
pattern and -- if it is found -- diagnoses it to be a certain ticket.

    #
    # This analyzer only applies to core files
    #
    if [[ "$THOTH_TYPE" != "core" ]]; then
    	exit 0
    fi

    #
    # This is only relevant for svc.startd
    #
    if [[ `cat $THOTH_INFO | json cmd` != "svc.startd" ]]; then
    	exit 0
    fi

    #
    # This is only OS-2359 if we have utmpx_postfork in our stack
    #
    if ( ! mdb -e ::stack $THOTH_DUMP | grep utmpx_postfork > /dev/null ); then
    	exit 0
    fi

    #
    # We have a winner! Set the ticket.
    #
    thoth_ticket OS-2359
    echo $THOTH_NAME: successfully diagnosed as OS-2359

Here's an analyzer that sets an `fmri` property to be that of the
`SMF_FMRI` environment variable:

    if [[ "$THOTH_TYPE" != "core" ]]; then
        exit 0
    fi

    if ( ! pargs -e $THOTH_DUMP | grep -w SMF_FMRI > /dev/null ); then
        exit 0
    fi

    fmri=`pargs -e $THOTH_DUMP | grep -w SMF_FMRI | cut -d= -f2-`
    thoth_set fmri $fmri
    echo $THOTH_NAME: $fmri

The output of analyzers is aggregated and displayed upon completion
of `analyze`.

#### Debugging analyzers

To debug and interactively develop analyzers, use `thoth debug` and
specify both the dump and the analyzer:

    % thoth debug 004a8bf33b2cd204903e46830a4f3b23 MANTA-1817-diagnose
    thoth: debugging 004a8bf33b2cd204903e46830a4f3b23
     * created interactive job -- 60061666-fdf4-466e-fd9c-d84eb7fbf2de
     * waiting for session... - established
    thoth: dump info is in $THOTH_INFO
    thoth: analyzer "MANTA-1817-diagnose" is in $THOTH_ANALYZER
    thoth: run "thoth_analyze" to run $THOTH_ANALYZER
    thoth: any changes to $THOTH_ANALYZER will be stored upon successful exit
    bcantrill@thoth #

This results in an interactive shell whereby one can interactively
edit the specified analyzer by editing the file referred to by
`$THOTH_ANALYZER` and can test the analyzer by running
`thoth_analyze`.  When the shell exits successfully (that is,
an exit of 0), the contents of the file pointed to by `$THOTH_ANALYZER`
will be written to the specified analyzer.

#### Testing analyzers

Once an analyzer works on a single dump using `thoth debug`,
it is recommended to run and debug the new analyzer on a single
dump by specifying the dump's complete hash to `analyze`; once the analyzer
is working, it can be run on a larger number of dumps by specifying a
broader dump specification to `analyze`.

### analyzer

Uploads stdin to be the named analyzer.

    $ thoth analyzer fmri < /var/tmp/fmri.sh
    thoth: reading analyzer 'fmri' from stdin
    thoth: added analyzer 'fmri'

### analyzers

Lists all of the analyzers known to thoth.  These are listed as absolute
Manta paths that may be retrieved with mget.

    $ thoth analyzers
    /thoth/stor/thoth/analyzers/MANTA-1579-diagnose
    /thoth/stor/thoth/analyzers/OS-1450-diagnose
    /thoth/stor/thoth/analyzers/OS-2359-diagnose
    /thoth/stor/thoth/analyzers/OS-2359-stacks
    /thoth/stor/thoth/analyzers/fmri

# Thoth and Triton

For users of Joyent's Triton (née SmartDataCenter), `sdc-thoth` allows for
Thoth to be integrated and run on a regular basis from the headnode.
`sdc-thoth` operates by querying compute nodes for dumps and their
corresponding hashes, checking those hashes against Thoth, and uploading any
missing dumps through the headnode and into Thoth.

## Installation

Running `sdc-thoth-install` as root on the headnode will install the
latest binary on the headnode in `/opt/custom`, create a `thoth`
user and create the necessary SMF manifest as well as a `crontab` that
runs `sdc-thoth` in dry-run mode.  The latest version can be grabbed via:

    curl -k \
      https://us-east.manta.joyent.com/thoth/public/thoth/thoth-sunos-latest.tar.gz | \
      (cd / && tar zxvf -)

Before running the script, you will need to have a running thoth database as
described above. Then:

    export SDC_ACCOUNT=thoth # or the Manta user that's hosting
    export SDC_URL=https://mycloudapi... # cloudapi endpoint for Triton
    export SDC_KEY_ID=... # key ID for that user
    export MANTA_URL=https://mymanta... # manta endpoint
    /opt/custom/thoth/bin/sdc-install-thoth

After installation, `su - thoth`, and try running `sdc-thoth`. If it's working
OK, you can edit `./run-thoth` to remove the `--dry-run` flag.

## License

The MIT License (MIT)
Copyright 2020 Joyent, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Bugs

See <https://github.com/joyent/manta-thoth/issues>.
