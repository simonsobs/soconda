
set -e
set -x

python -m pip install -vvv --ignore-installed --no-deps --prefix "${CONDA_PREFIX}" .

# Run tests
#pytest "${SRC_DIR}/pixell/tests"
