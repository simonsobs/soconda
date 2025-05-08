# This script is sourced in the main `soconda.sh` script.
# Any commands placed here will be executed within that shell
# and have access to all environment variables defined there.
# There are 2 variables defined here which control the optional
# creation of a modulefile to load the environment and also
# which create a small script that installs a jupyter kernel
# for the environment into a user's home directory.

# Install a module file?
install_module=no

# Install jupyter kernel setup script?
install_jupyter_setup=no

# Add any other shell commands here for this system...

# Add radical.pilot SO config in the correct folder.
cp ${script_dir}/templates/resource_so.json ${CONDA_PREFIX}/lib/python${python_major_minor}/site-packages/radical/pilot/configs/