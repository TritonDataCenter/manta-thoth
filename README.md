manta-thoth
===========

Thoth is a Manta-based system for core and crash dump management for
illumos-derived systems like SmartOS, OmniOS, DelphixOS, Nexenta, etc. --
though in principle it can operate on any system that generates ELF
core files.  With Thoth, dumps can be moved exactly once -- into Manta --
and then be debugged, analyzed, archived and reported upon without
further data movement.

# Installation

    $ npm install git://github.com/joyent/manta-thoth.git#master

# Setup

As with the [node-manta](http://github.com/node-manta) CLI tools, you will
need to set Manta environment variables that match your Joyent Manta account:

    $ export MANTA_KEY_ID=`ssh-keygen -l -f ~/.ssh/id_rsa.pub | awk '{print $2}' | tr -d '\n'`
    $ export MANTA_URL=https://us-east.manta.joyent.com
    $ export MANTA_USER=bcantrill

# Running Thoth

## Introduction

Thoth consists primarily of the ```thoth``` utility,
a veneer on Manta that
generates a _hash_ unique to a core or crash dump, uploads that
dump to a directory under ```$MANTA_USER/stor/thoth```, and offers
facilities to list, filter and (most importantly) debug those dumps
in place.  Most ```thoth``` subcommands operate on a _dump specification_:
a dump's hash (or substring thereof) or a space-delimited set of
constraints based on its properties.  A constraint consists of
a property name, a single equals sign, and the value (or globbed expression)
to match.  For example, to list
all crash dumps from the node  95SY9R1

    $ thoth ls type=crash node=95SY9R1

The special token ```undefined``` denotes a property that isn't set.
For example, to
list all dumps that begin with ```svc``` that don't have a ticket:

    $ thoth ls cmd=svc* ticket=undefined
    thoth: creating job to list
    thoth: created job 3f5f8e94-6fbe-400b-b7d5-a666a2012066
    thoth: waiting for completion of job 3f5f8e94-6fbe-400b-b7d5-a666a2012066
    thoth: job 3f5f8e94-6fbe-400b-b7d5-a666a2012066 completed in 0h0m26s
    DUMP             TYPE  TIME                NODE/CMD         TICKET
    8eaa35bb82c20716 core  2013-06-26T17:01:29 svc.startd       -
    06880c6f00a2ab47 core  2013-06-26T18:04:56 svc.startd       -
    8df0e4e9d9a67581 core  2013-06-26T18:04:57 svc.startd       -
    9a1ec403c6e78b95 core  2013-06-26T19:04:24 svc.startd       -
    ddaca0c9fbae4ff6 core  2013-06-26T19:23:41 svc.startd       -
    b791a00a788c9d59 core  2013-06-27T01:26:05 svc.configd      -
    3dae4877554defc4 core  2013-07-06T07:02:38 svc.configd      -
    7866184c07c23510 core  2013-07-11T04:47:56 svc.startd       -
    e407e3820d3af9ab core  2013-07-11T04:47:56 svc.startd       -

## Subcommands

```thoth``` operates by specifying a subcommand.  Many subcommands kick
off Manta jobs, and the job ID is presented in the command line
(allowing Manta tools like [```mjob```](https://github.com/joyent/node-manta/blob/master/docs/man/mjob.md) to be used to observe or debug behavior).
In general, success is denoted by an exit status 0 and failure by an
exit status of 1 -- but some subcommands can exit with other status
codes (notably, ```info```).
The following subcommands are supported:

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

Note that for the ```info``` subcommand, a dump specification can also consist
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

Results in an interactive debugging session debugging the specified dump
via [mlogin](http://blog.sysmgr.org/2013/06/manta-mlogin.html).

### ls

Lists the dumps that match the dump specification, or all dumps if no
dump specification is provided.  A dump abbreviation, the dump type, the
time, the node or command, and the ticket are provided for each dump.
By default, the dumps are listed in time order from oldest to newest.

### object

For a given local dump, provides the hashed name of the object.

    $ thoth object core.19972
    3e166b93871e7747c799008f58bd30b9

This can be used to automate uploads of dumps.

### report

Gives a JSON report of the given property across the given dump specification.
For example, here's a report of ```platform``` for cores from the
command ```svc.startd```:

    $ thoth report cmd=svc.startd platform
    {
      "joyent_20130625T221319Z": 47,
      "joyent_20130613T200352Z": 57
    }

### set

Sets a user property, which will appear in the ```properties``` field of the
JSON blob retrieved via ```info```.  The value for the property can be
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
in a dump specification by using the special token ```undefined```.

### ticket

Sets a ticket on a dump, a field of arbitrary alphanumeric characters
purely for being able to associate the dump with a defect tracking system.

### unticket

Unsets a ticket on a dump.

### analyze

On the specified dumps, runs the specified analyzer, as uploaded via the
```analyzer``` subcommand.  An analyzer is a shell script that runs in the
context of a Manta job on a dump.  The following shell variables are made
available in the context of an analyzer:

* ```$THOTH_DUMP```: The path of the dump.  (This is set to the same
  value as ```$MANTA_INPUT_FILE```.)

* ```$THOTH_INFO```: The path of a local file that contains the JSON
  info for the dump.  The [json](https://github.com/trentm/json) utility
  exists in the context of a Manta job, and this may be used to parse this
  file.

* ```$THOTH_TYPE```: The type of the dump (either ```crash``` or ```core```).

* ```$THOTH_NAME```: The full name (that is, hash) of the dump.

* ```thoth_set```: A shell function that will set the specified property
  to the specified value or, if no value is specified, standard input.

* ```thoth_unset```: A shell function that will unset the specified property
  on the dump being analyzed.

* ```thoth_ticket```: A shell function that will set the ticket on the
  dump being analyzed to the ticket specified.

* ```thoth_unticket```: A shell function that will unset the ticket on the
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

Here's an analyzer that sets an ```fmri``` property to be that of the
```SMF_FMRI``` environment variable:

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
of ```analyze```.  

#### Debugging analyzers

To debug and interactively develop analyzers, use ```thoth debug``` and
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
```$THOTH_ANALYZER``` and can test the analyzer by running 
```thoth_analyze```.  When the shell exits successfully (that is,
an exit of 0), the contents of the file pointed to by ```$THOTH_ANALYZER```
will be written to the specified analyzer.

#### Testing analyzers

Once an analyzer works on a single dump using ```thoth debug```,
it is recommended to run and debug the new analyzer on a single
dump by specifying the dump's complete hash to ```analyze```; once the analyzer
is working, it can be run on a larger number of dumps by specifying a
broader dump specification to ```analyze```.

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

# Thoth and SmartDataCenter

For users of Joyent's SmartDataCanter, ```sdc-thoth``` allows for Thoth to
be integrated and run on a regular basis from the head-node.  ```sdc-thoth```
operates by querying compute nodes for dumps and their
corresponding hashes, checking those hashes against Thoth, and uploading
any missing dumps through the head-node and into Thoth.

## Installation

Running ```sdc-thoth-install``` as root on the head-node will install the
latest binary on the head-node in ```/opt/custom```, create a ```thoth```
user and create the necessary SMF manifest as well as a ```crontab``` that
runs ```sdc-thoth``` in dry-run mode.  You can also download and execute
this directly from Manta (with the obvious caveats that you should really
never just pipe the output of ```curl``` to ```bash``` running
as ```root```):

    # curl -k https://us-east.manta.joyent.com/thoth/public/sdc-thoth-install | bash

## License

The MIT License (MIT)
Copyright (c) 2013 Joyent

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
