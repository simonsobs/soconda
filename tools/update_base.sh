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

if [ -z ${base} ]; then
    show_help
    exit 1
fi

echo "Updating conda base ..."

# Activate base and update conda tools
source "${base}/etc/profile.d/conda.sh"
conda activate base
conda update -n base --yes --all conda
conda install -n base --yes --all conda-build conda-index
conda deactivate
