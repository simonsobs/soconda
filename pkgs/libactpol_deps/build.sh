
set -e
set -x

pushd sla_refro-moby2-1
PREFIX="${PREFIX}" make
PREFIX="${PREFIX}" make install
popd

pushd sofa_20180130
PREFIX="${PREFIX}" make
PREFIX="${PREFIX}" make install
popd

pushd slim_v2_7_1-moby2-1
CFLAGS="-O3 -g -fPIC" \
CXXFLAGS="-O3 -g -fPIC" \
./configure --prefix="${PREFIX}" --with-zzip && \
make && \
make install
rm -f "${PREFIX}/lib/libactpol_deps*.la"
popd
