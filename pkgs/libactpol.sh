#!/bin/bash

pkg="libactpol"
version=c0c1647ad62b418f34fe38eb73168d4f2e13ff6f
psrc=${pkg}-${version}
pfile=${psrc}.tar.gz

# Top directory
pushd $(dirname $(dirname $0)) >/dev/null 2>&1
topdir=$(pwd)
popd >/dev/null 2>&1

fetched=$(eval "${topdir}/tools/fetch_check.sh" https://github.com/ACTCollaboration/libactpol/archive/${version}.tar.gz ${pfile})

if [ "x${fetched}" = "x" ]; then
    echo "Failed to fetch ${pkg}"
    exit 1
fi

echo "Building ${pkg}..."

rm -rf ${psrc}
tar xzf ${fetched} \
    && pushd ${psrc} \
    && sed -i -e 's/AC_FUNC_MALLOC/\#AC_FUNC_MALLOC/g' configure.ac \
    && autoreconf -i \
    && CFLAGS="-O3 -g -fPIC" \
    ./configure --enable-shared --disable-oldact \
    --disable-slalib --prefix="${CONDA_PREFIX}" \
    && PREFIX="${CONDA_PREFIX}" make \
    && PREFIX="${CONDA_PREFIX}" make install \
    && popd

if [ $? -ne 0 ]; then
    echo "Failed to build ${pkg}"
    exit 1
fi

echo "Finished building ${pkg}"
