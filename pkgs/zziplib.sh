#!/bin/bash

pkg="zziplib"
version=0.13.72
psrc=${pkg}-${version}
pfile=${psrc}.tar.gz

# Top directory
pushd $(dirname $(dirname $0)) >/dev/null 2>&1
topdir=$(pwd)
popd >/dev/null 2>&1

fetched=$(eval "${topdir}/tools/fetch_check.sh" https://github.com/gdraheim/zziplib/archive/v${version}.tar.gz ${pfile})

if [ "x${fetched}" = "x" ]; then
    echo "Failed to fetch ${pkg}"
    exit 1
fi

echo "Building ${pkg}..."

rm -rf ${psrc}
tar xzf ${fetched} \
    && pushd ${psrc} \
    && mkdir -p build \
    && pushd build \
    && cmake \
    -DCMAKE_C_COMPILER="${CC}" \
    -DCMAKE_C_FLAGS="-O3 -g -fPIC" \
    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
    -DCMAKE_INSTALL_PREFIX="${CONDA_PREFIX}" .. \
    && make -j 4 install \
    && popd \
    && popd

if [ $? -ne 0 ]; then
    echo "Failed to build ${pkg}"
    exit 1
fi

echo "Finished building ${pkg}"
