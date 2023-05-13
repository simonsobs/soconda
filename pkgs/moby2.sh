#!/bin/bash

pkg="moby2"
version=fd360a7352c88d3eb5195f5f0ea331ddc24e5e09
psrc=${pkg}-${version}
pfile=${psrc}.tar.gz

# Top directory
pushd $(dirname $(dirname $0)) >/dev/null 2>&1
topdir=$(pwd)
popd >/dev/null 2>&1

fetched=$(eval "${topdir}/tools/fetch_check.sh" https://github.com/ACTCollaboration/moby2/archive/${version}.tar.gz ${pfile})

if [ "x${fetched}" = "x" ]; then
    echo "Failed to fetch ${pkg}"
    exit 1
fi

echo "Building ${pkg}..."

rm -rf ${psrc}
tar xzf ${fetched} \
    && pushd ${psrc} \
    && patch -p1 < "${topdir}/pkgs/moby2.sh.patch" \
    && python3 setup.py build \
    && python3 setup.py install --prefix "${CONDA_PREFIX}" \
    && popd

if [ $? -ne 0 ]; then
    echo "Failed to build ${pkg}"
    exit 1
fi

echo "Finished building ${pkg}"
