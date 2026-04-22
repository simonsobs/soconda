# This script is sourced in the main `soconda.sh` script.
# Any commands placed here will be executed within that shell
# and have access to all environment variables defined there.
# There are 2 variables defined here which control the optional
# creation of a modulefile to load the environment and also
# which create a small script that installs a jupyter kernel
# for the environment into a user's home directory.

# Install a module file?
install_module=yes

# Install jupyter kernel setup script?
install_jupyter_setup=yes

# Add any other shell commands here for this system...

# Add radical.pilot SO config in the correct folder.
python ${scriptdir}/tools/update_resource.py \
       --config ${config} \
       --base-json ${scriptdir}/templates/resource_so.json \
       --output-json ${CONDA_PREFIX}/lib/python${python_major_minor}/site-packages/radical/pilot/configs/resource_so.json \
       --env-path ${CONDA_PREFIX}


conda_exec env config vars set SOPATH=/global/cfs/cdirs/sobs
conda_exec env config vars set PKG_CONFIG_PATH=$CONDA_PREFIX/lib/pkgconfig:$CONDA_PREFIX/share/pkgconfig:$PKG_CONFIG_PATH
conda_exec deactivate
conda_exec activate "${fullenv}"

mkdir -p $CONDA_PREFIX/git

echo ''
echo ''
cd $CONDA_PREFIX/git
git clone https://github.com/amaurea/fast_g3.git
cd $CONDA_PREFIX/git/fast_g3
make clean && make -j4 && ln -sf $CONDA_PREFIX/git/fast_g3/fast_g3 $CONDA_PREFIX/lib/python${python_major_minor}/site-packages/fast_g3

echo ''
echo ''
cd $CONDA_PREFIX/git
git clone https://github.com/amaurea/cpu_mm.git
cd $CONDA_PREFIX/git/cpu_mm
make clean && make -j4 && ln -sf $CONDA_PREFIX/git/cpu_mm/python $CONDA_PREFIX/lib/python${python_major_minor}/site-packages/cpu_mm

echo ''
echo ''
cd $CONDA_PREFIX/git
git clone https://github.com/amaurea/gpu_mm.git
cd $CONDA_PREFIX/git/gpu_mm
make clean && make -j4 && ln -sf $CONDA_PREFIX/git/gpu_mm/gpu_mm $CONDA_PREFIX/lib/python${python_major_minor}/site-packages/gpu_mm

echo ''
echo ''
cd $CONDA_PREFIX/git
git clone https://github.com/amaurea/sogma.git
cd $CONDA_PREFIX/git/sogma
ln -sf $CONDA_PREFIX/git/sogma/python $CONDA_PREFIX/lib/python${python_major_minor}/site-packages/sogma
ln -sf $CONDA_PREFIX/git/sogma/bin/sogma $CONDA_PREFIX/bin/sogma
ln -sf $CONDA_PREFIX/git/sogma/bin/solist $CONDA_PREFIX/bin/solist
ln -sf $CONDA_PREFIX/git/sogma/bin/soplanet $CONDA_PREFIX/bin/soplanet
ln -sf $CONDA_PREFIX/git/sogma/bin/sosplit $CONDA_PREFIX/bin/sosplit

echo ''
echo ''
cd $CONDA_PREFIX/git
git clone https://github.com/amaurea/tenki.git
ln -sf $CONDA_PREFIX/git/tenki/enplot $CONDA_PREFIX/bin/enplot

echo ''
echo ''
cd $CONDA_PREFIX/git
git clone git@github.com:simonsobs/sotodlib.git
pip install -e sotodlib

