#!/bin/bash

# Location of this script
pushd $(dirname $0) >/dev/null 2>&1
scriptdir=$(pwd)
popd >/dev/null 2>&1

show_help () {
    echo "" >&2
    echo "Usage:  $0 <base install directory> <optional arch string>" >&2
    echo "" >&2
}

base=$1
arch=$2

if [ -z ${base} ]; then
    show_help
    exit 1
fi

if [ -z ${arch} ]; then
    arch="$(uname)-$(uname -m)"
fi

echo "Bootstrap conda base for architecture ${arch} ..."

inst=$(eval "${scriptdir}/fetch_check.sh" https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-${arch}.sh miniforge.sh)

bash "${inst}" -b -f -p "${base}"

# Create base config file
echo "# condarc bootstrapped by soconda" > "${base}/.condarc"
echo "channels:" >> "${base}/.condarc"
echo "  - conda-forge" >> "${base}/.condarc"
echo "changeps1: false" >> "${base}/.condarc"

# Activate base and update conda tools
source "${base}/etc/profile.d/conda.sh"
conda activate base
conda update -n base --yes --all conda
conda install -n base --yes --all conda-build conda-index
conda deactivate
