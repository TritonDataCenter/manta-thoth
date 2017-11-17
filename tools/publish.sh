#!/bin/bash

ver="$1"
uname=$(uname -s | tr "[:upper:]" "[:lower:]")
name="thoth-${uname}-${ver:?}.tar.gz"
latest="thoth-${uname}-latest.tar.gz"

mput -f "$name" "/thoth/public/$name"
mln "/thoth/public/$name" "/thoth/public/$latest"
