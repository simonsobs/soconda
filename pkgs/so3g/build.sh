
set -e
set -x

CFLAGS="-O3 -g -fPIC" \
CXXFLAGS='-O3 -g -fPIC -std=c++14' \
BOOST_ROOT="${PREFIX}" \
FLAC_ROOT="${PREFIX}" \
pip install -vvv --prefix "${PREFIX}" .
