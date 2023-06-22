
set -e
set -x

python3 setup.py build
python3 setup.py install --prefix "${PREFIX}"

