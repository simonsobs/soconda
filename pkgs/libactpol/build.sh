
set -e
set -x

sed -i -e 's/AC_FUNC_MALLOC/\#AC_FUNC_MALLOC/g' configure.ac
autoreconf -i

CFLAGS="-O3 -g -fPIC" \
./configure --enable-shared --disable-oldact \
--disable-slalib --prefix="${PREFIX}"

make
make install
