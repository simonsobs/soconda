set -e
set -x

# Ensure that stale build products are removed
rm -rf build

CFLAGS="-Wno-error -O3 -fPIC -I${PREFIX}/include" \
FLAC_ROOT="${PREFIX}" \
python -m pip install -vvv --ignore-installed --no-deps --prefix "${PREFIX}" .
