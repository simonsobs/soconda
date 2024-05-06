#!/bin/bash

# This assumes that a conda base environment already exists
# in /opt/conda, and that we want to install soconda directly
# to the base environment.

# Location for conda base
base_dir=/opt/conda

# Location of soconda tree.  This is assumed to be already
# checked out to the desired branch / tag.  This is useful for
# testing if the source tree is bind-mounted somewhere else.
git_dir="."

# Temp package dir
pkg_temp=${HOME}/temp_pkgs
mkdir -p ${pkg_temp}
export CONDA_PKGS_DIRS=${pkg_temp}

#===========================================

# Base environment is already activated
conda update -n base --yes --all conda
conda install -n base --yes --all conda-build conda-verify

# Build things from the default home directory

eval "${git_dir}/soconda.sh" \
    -v "$(date +%Y%m%d)" \
    -c "site" \
    -b "/opt/conda" \
    -e "base"

# Remove pkg cache
rm -rf ${pkg_temp}
