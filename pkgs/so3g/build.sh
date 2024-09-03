
set -e
set -x

CFLAGS="-Wno-error -O3 -fPIC -I${PREFIX}/include" \
CXXFLAGS="-Wno-error -O3 -fPIC -std=c++14 -I${PREFIX}/include" \
BOOST_ROOT="${PREFIX}" \
FLAC_ROOT="${PREFIX}" \
python -m pip install -vvv --ignore-installed --no-deps --prefix "${PREFIX}" .
