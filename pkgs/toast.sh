#!/bin/bash

pkg="toast"
version=3.0.0a15
psrc=${pkg}-${version}
pfile=${psrc}.tar.gz

# Top directory
pushd $(dirname $(dirname $0)) >/dev/null 2>&1
topdir=$(pwd)
popd >/dev/null 2>&1

fetched=$(eval "${topdir}/tools/fetch_check.sh" https://github.com/hpc4cmb/toast/archive/${version}.tar.gz ${pfile})

if [ "x${fetched}" = "x" ]; then
    echo "Failed to fetch ${pkg}"
    exit 1
fi

echo "Building ${pkg}..."

rm -rf ${psrc}
tar xzf ${fetched} \
    && pushd ${psrc} \
    && CIBUILDWHEEL=1 ./platforms/conda.sh \
    && popd

if [ $? -ne 0 ]; then
    echo "Failed to build ${pkg}"
    exit 1
fi

echo "Finished building ${pkg}"
