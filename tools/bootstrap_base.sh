#!/bin/bash

# Location of this script
pushd $(dirname $0) >/dev/null 2>&1
scriptdir=$(pwd)
popd >/dev/null 2>&1

show_help () {
    echo "" >&2
    echo "Usage:  $0 <base install directory>" >&2
    echo "" >&2
}

base=$1

if [ "x${base}" = "x" ]; then
    show_help
    exit 1
fi

inst=$(eval "${scriptdir}/fetch_check.sh" https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh miniforge.sh)

bash "${inst}" -b -f -p "${base}"

# Activate base and install libmamba solver
source "${base}/etc/profile.d/conda.sh"
conda activate base
conda update -n base --yes conda
conda install -n base --yes conda-libmamba-solver
conda deactivate

# Create base config file
echo "# condarc bootstrapped by soconda" > "${base}/.condarc"
echo "channels:" >> "${base}/.condarc"
echo "  - conda-forge" >> "${base}/.condarc"
echo "changeps1: false" >> "${base}/.condarc"
echo "solver: libmamba" >> "${base}/.condarc"

