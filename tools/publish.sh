#!/bin/bash

ver="$1"
uname=$(uname -s | tr "[:upper:]" "[:lower:]")
commit=$(git rev-parse --short HEAD)
name="thoth-${uname}-${ver:?}-${commit:?}.tar.gz"
latest="thoth-${uname}-latest.tar.gz"

mput -f "$name" "/thoth/public/$name"
mln "/thoth/public/$name" "/thoth/public/$latest"
