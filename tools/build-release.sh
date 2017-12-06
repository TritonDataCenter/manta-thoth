#!/bin/bash

if [[ -n "$TRACE" ]]; then
    export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -o xtrace
fi

set -o errexit

node_ver='0.10.38'
thoth_ver=$(json -f package.json version)
gcc_ver=$(pkg_info -E gcc4? | cut -d - -f 1)
thoth_commit=$(git rev-parse --short HEAD)
uname=$(uname -s | tr "[:upper:]" "[:lower:]")
case "$uname" in
    darwin) node_arch='x64';;
    sunos) node_arch='x86';;
    *) printf 'Sorry, not ready for you'; exit 1;;
esac
tar="thoth-${uname}-${thoth_ver}-${thoth_commit}.tar.gz"
node_dir="node-v${node_ver}-${uname}-${node_arch}"
node_tar="${node_dir}.tar.gz"
node_location="https://nodejs.org/download/release/v${node_ver}"

base="$PWD"
proto=$(mktemp -d -t thoth-build.XXXXXX)
cd "$proto"

curl -#LOC - "${node_location}/${node_tar}"
tar zxf "$node_tar"

export PATH="${PWD}/${node_dir}/bin:$PATH"
export LD_LIBRARY_PATH="/opt/local/${gcc_ver}/lib/"

mkdir -p opt/custom/thoth/{bin,lib}
cp "${node_dir}/bin/node" opt/custom/thoth/bin
if [[ $uname == sunos ]]; then
    cp "/opt/local/${gcc_ver}/lib/libstdc++.so.6" opt/custom/thoth/lib
    cp "/opt/local/${gcc_ver}/lib/libgcc_s.so.1" opt/custom/thoth/lib
fi
npm install smartdc "$base"
mv node_modules opt/custom/thoth/node_modules

tar zcf "$tar" opt
mv "$tar" "$base"
#rm -rf "$proto"
