
set -e
set -x

pushd sla_refro-moby2-1
PREFIX="${CONDA_PREFIX}" make -j $CPU_COUNT
PREFIX="${CONDA_PREFIX}" make install
popd

pushd sofa_20180130
PREFIX="${CONDA_PREFIX}" make -j $CPU_COUNT
PREFIX="${CONDA_PREFIX}" make install
popd

pushd slim_v2_7_1-moby2-1
CFLAGS="-O3 -g -fPIC" ./configure --prefix="${CONDA_PREFIX}" --with-zzip
make -j $CPU_COUNT
make install
popd
