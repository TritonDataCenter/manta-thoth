#!/bin/bash

if [[ -n "$TRACE" ]]; then
    export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -o xtrace
fi

set -o errexit

node_ver='0.10.38'
thoth_ver=$(json -f package.json version)
uname=$(uname -s | tr "[:upper:]" "[:lower:]")
case "$uname" in
    darwin) node_arch='x64';;
    sunos) node_arch='x86';;
    *) printf 'Sorry, not ready for you'; exit 1;;
esac
tar="thoth-${uname}-${thoth_ver}.tar.gz"
node_dir="node-v${node_ver}-${uname}-${node_arch}"
node_tar="${node_dir}.tar.gz"
node_location="https://nodejs.org/download/release/v${node_ver}"

base="$PWD"
proto=$(mktemp -d -t thoth-build.XXXXXX)
cd "$proto"

curl -#LOC - "${node_location}/${node_tar}"
tar zxf "$node_tar"

mkdir -p opt/custom/thoth/{bin,lib}
cp "${node_dir}/bin/node" opt/custom/thoth/bin
if [[ $uname == sunos ]]; then
    cp /opt/local/gcc47/lib/libstdc++.so.6 opt/custom/thoth/lib
    cp /opt/local/gcc47/lib/libgcc_s.so.1 opt/custom/thoth/lib
fi
(
    cd opt/custom/thoth
    npm install smartdc manta-thoth
)

tar zcf "$tar" opt
mv "$tar" "$base"
#rm -rf "$proto"
