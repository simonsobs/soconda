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

# Forcibly replace the conda pyfftw package with the wheel
# until this upstream PR is merged:
# https://github.com/conda-forge/pyfftw-feedstock/pull/60
pip install --upgrade --no-deps --force-reinstall pyfftw
