#!/bin/bash

# Location of this script
pushd $(dirname $0) >/dev/null 2>&1
scriptdir=$(pwd)
popd >/dev/null 2>&1


# Install local packages

while IFS='' read -r line || [[ -n "${line}" ]]; do
    # Is this line commented?
    comment=$(echo "${line}" | cut -c 1)
    if [ "${comment}" != "#" ]; then
        pkgname="${line}"
        pkgrecipe="${scriptdir}/pkgs/${pkgname}"
        echo "Building package ${pkgname}"
        eval "conda-build ${pkgrecipe}" 2>&1 | tee "log_${pkgname}"
        echo "Installing package ${pkgname}"
        eval "conda install --yes --use-local ${pkgname}"
    fi
done < "${scriptdir}/packages_local.txt"
