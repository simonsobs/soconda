#!/bin/bash

pkg="so3g"
version=0.1.6
psrc=${pkg}-${version}
pfile=${psrc}.tar.gz

# Top directory
pushd $(dirname $(dirname $0)) >/dev/null 2>&1
topdir=$(pwd)
popd >/dev/null 2>&1

fetched=$(eval "${topdir}/tools/fetch_check.sh" https://github.com/simonsobs/so3g/archive/v${version}.tar.gz ${pfile})

if [ "x${fetched}" = "x" ]; then
    echo "Failed to fetch ${pkg}"
    exit 1
fi

echo "Building ${pkg}..."

rm -rf ${psrc}
tar xzf ${fetched} \
    && pushd ${psrc} \
    && CFLAGS='-O3 -g -fPIC' \
    CXXFLAGS='-O3 -g -fPIC -std=c++14' \
    BOOST_ROOT="${CONDA_PREFIX}" \
    FLAC_ROOT="${CONDA_PREFIX}" \
    pip install -vvv . \
    && popd

if [ $? -ne 0 ]; then
    echo "Failed to build ${pkg}"
    exit 1
fi

echo "Finished building ${pkg}"
