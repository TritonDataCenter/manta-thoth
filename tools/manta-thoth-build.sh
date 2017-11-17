#!/bin/bash -x

set -o errexit

job=$(
mjob create --close -r 'set -o errexit ;
cd /var/tmp ;
git clone https://github.com/joyent/manta-thoth ;
cd manta-thoth ;
make publish')
mjob watch "$job"
