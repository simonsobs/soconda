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


if [ $(uname -s) = "Linux" ]; then
    inst=$(eval "${scriptdir}/fetch_check.sh" https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname -s)-$(uname -m).sh miniforge.sh)
else
    if [ $(uname -s) = "Darwin" ]; then
        inst=$(eval "${scriptdir}/fetch_check.sh" https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-$(uname -m).sh miniforge.sh)
    else
        echo "Unsupported operating system" >&2
        exit 1
    fi
fi

bash "${inst}" -b -f -p "${base}" \
    && echo "# condarc for soconda" > "${base}/.condarc" \
    && echo "channels:" >> "${base}/.condarc" \
    && echo "  - conda-forge" >> "${base}/.condarc" \
    && echo "channel_priority: strict" >> "${base}/.condarc" \
    && echo "changeps1: false" >> "${base}/.condarc"

