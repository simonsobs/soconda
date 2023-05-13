#!/bin/bash

pkg="libactpol_deps"
version=db0aee380dad503ba8fdf058d4d8075387100758
psrc=${pkg}-${version}
pfile=${psrc}.tar.gz

# Top directory
pushd $(dirname $(dirname $0)) >/dev/null 2>&1
topdir=$(pwd)
popd >/dev/null 2>&1

fetched=$(eval "${topdir}/tools/fetch_check.sh" https://github.com/ACTCollaboration/libactpol_deps/archive/${version}.tar.gz ${pfile})

if [ "x${fetched}" = "x" ]; then
    echo "Failed to fetch ${pkg}"
    exit 1
fi

echo "Building ${pkg}..."

rm -rf ${psrc}
tar xzf ${fetched} \
    && pushd ${psrc}/sla_refro-moby2-1 \
    && PREFIX="${CONDA_PREFIX}" make \
    && PREFIX="${CONDA_PREFIX}" make install \
    && popd \
    && pushd ${psrc}/sofa_20180130 \
    && PREFIX="${CONDA_PREFIX}" make \
    && PREFIX="${CONDA_PREFIX}" make install \
    && popd \
    && pushd ${psrc}/slim_v2_7_1-moby2-1 \
    && CFLAGS="-O3 -g -fPIC" ./configure --prefix="${CONDA_PREFIX}" --with-zzip \
    && make install \
    && popd

if [ $? -ne 0 ]; then
    echo "Failed to build ${pkg}"
    exit 1
fi

echo "Finished building ${pkg}"
