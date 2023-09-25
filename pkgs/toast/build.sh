
set -e
set -x

declare -a CMAKE_PLATFORM_FLAGS
if [[ ${HOST} =~ .*darwin.* ]]; then
    CMAKE_PLATFORM_FLAGS+=(-DCMAKE_OSX_SYSROOT="${CONDA_BUILD_SYSROOT}")
    # export LDFLAGS=$(echo "${LDFLAGS}" | sed "s/-Wl,-dead_strip_dylibs//g")
else
    CMAKE_PLATFORM_FLAGS+=(-DCMAKE_TOOLCHAIN_FILE="${RECIPE_DIR}/cross-linux.cmake")
fi

if [[ ${DEBUG_C} == yes ]]; then
    CMAKE_BUILD_TYPE=Debug
else
    CMAKE_BUILD_TYPE=Release
fi

echo "DBG:  PATH=${PATH}"
echo "DBG:  PYTHON=${PYTHON}"
echo "DBG:  python3=$(which python3)"
echo "DBG:  PY_VER=${PY_VER}"

mkdir -p build
cd build
cmake \
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} \
    ${CMAKE_PLATFORM_FLAGS[@]} \
    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
    -DPython3_EXECUTABLE=$(which python3) \
    -DPython3_INCLUDE_DIR="${PREFIX}/include/python${PY_VER}" \
    -DPython3_FIND_VIRTUALENV=ONLY \
    -DCMAKE_C_COMPILER="${CC}" \
    -DCMAKE_CXX_COMPILER="${CXX}" \
    -DCMAKE_C_FLAGS="-O3 -g -fPIC" \
    -DCMAKE_CXX_FLAGS="-O3 -g -fPIC" \
    -DCMAKE_VERBOSE_MAKEFILE=1 \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_PREFIX_PATH="${PREFIX}" \
    -DFFTW_ROOT="${PREFIX}" \
    -DAATM_ROOT="${PREFIX}" \
    -DBLAS_LIBRARIES="${PREFIX}/lib/libblas${SHLIB_EXT}" \
    -DLAPACK_LIBRARIES="${PREFIX}/lib/liblapack${SHLIB_EXT}" \
    -DSUITESPARSE_INCLUDE_DIR_HINTS="${PREFIX}/include" \
    -DSUITESPARSE_LIBRARY_DIR_HINTS="${LIBDIR}" \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_PREFIX_PATH="${PREFIX}" \
    "${SRC_DIR}"
make -j $CPU_COUNT
make install
