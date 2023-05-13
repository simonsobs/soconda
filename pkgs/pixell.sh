#!/bin/bash

pkg="pixell"
version=0.17.3
psrc=${pkg}-${version}
pfile=${psrc}.tar.gz

# Top directory
pushd $(dirname $(dirname $0)) >/dev/null 2>&1
topdir=$(pwd)
popd >/dev/null 2>&1

fetched=$(eval "${topdir}/tools/fetch_check.sh" https://github.com/simonsobs/pixell/archive/v${version}.tar.gz ${pfile})

if [ "x${fetched}" = "x" ]; then
    echo "Failed to fetch ${pkg}"
    exit 1
fi

echo "Building ${pkg}..."

rm -rf ${psrc}
tar xzf ${fetched} \
    && pushd ${psrc} \
    && python setup.py install --prefix "${CONDA_PREFIX}" \
    && popd

if [ $? -ne 0 ]; then
    echo "Failed to build ${pkg}"
    exit 1
fi

echo "Finished building ${pkg}"
