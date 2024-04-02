
set -e
set -x

CFLAGS="-O3 -g -fPIC -I${PREFIX}/include" \
CXXFLAGS='-O3 -g -fPIC -std=c++14' \
BOOST_ROOT="${PREFIX}" \
FLAC_ROOT="${PREFIX}" \
python -m pip install -vvv --ignore-installed --no-deps --prefix "${PREFIX}" .
