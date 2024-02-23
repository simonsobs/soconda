#!/bin/bash

# Location of this script
pushd $(dirname $0) >/dev/null 2>&1
scriptdir=$(pwd)
popd >/dev/null 2>&1

show_help () {
    echo "" >&2
    echo "Usage:  $0" >&2
    echo "    [-e <environment, either name or full path>]" >&2
    echo "    [-v <python version (python 3.10 used by default)>]" >&2
    echo "    [-m <modulefile dir (default is <env>/modulefiles)>]" >&2
    echo "" >&2
    echo "    Create a conda environment for Simons Observatory." >&2
    echo "" >&2
    echo "" >&2
}

envname=""
version=""
moduledir=""

while getopts ":e:v:m:" opt; do
    case $opt in
        e)
            envname=$OPTARG
            ;;
        v)
            version=$OPTARG
            ;;
        m)
            moduledir=$OPTARG
            ;;
        \?)
            show_help
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            show_help
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

module load openmpi/gcc/4.1.1 anaconda3/2022.10
MPICC=`which mpicc`

if [ -z "${version}" ]; then
    # Get the version from git
    version='3.10'
fi

if [ -z "${envname}" ]; then
    echo "Environment root name not specified, using \"soconda\""
    envname="soconda"
fi

# The env root name, used for the name of the generated module file
envroot=$(basename ${envname})

# The full environment name, including the root and version.
fullenv="${envname}_${version}"

if [ -z "$(which conda)" ]; then
    # conda is not in the path
    echo "You must either activate the conda base environment before"
    echo "running this script, or you must specify the path to the base"
    echo "install with the \"-b <path to base>\" option."
    exit 1
else
    # Conda is in the path
    conda_dir="$(dirname $(dirname $(which conda)))"
fi
# Determine whether the new environment is a name or a full path.
env_noslash=$(echo "${fullenv}" | sed -e 's/\///g')
is_path=no
if [ "${env_noslash}" != "${fullenv}" ]; then
    # This was a path
    is_path=yes
    env_check=""
    if [ -e "${fullenv}/bin/conda" ]; then
        # It already exists
        env_check="${fullenv}"
    fi
else
    env_check=$(conda env list | grep "${fullenv} ")
fi

if [ -z "${env_check}" ]; then
    # Environment does not yet exist.  Create it.
    if [ ${is_path} = "no" ]; then
        echo "Creating new environment \"${fullenv}\""
        conda create --yes -n "${fullenv}"
    else
        echo "Creating new environment \"${fullenv}\""
        conda create --yes -p "${fullenv}"
    fi
    echo "Activating environment \"${fullenv}\""
    conda activate "${fullenv}"

    # Create condarc for this environment
    echo "# condarc for soconda" > "${CONDA_PREFIX}/.condarc"
    echo "channels:" >> "${CONDA_PREFIX}/.condarc"
    echo "  - conda-forge" >> "${CONDA_PREFIX}/.condarc"
    echo "  - nodefaults" >> "${CONDA_PREFIX}/.condarc"
    echo "changeps1: true" >> "${CONDA_PREFIX}/.condarc"
    echo "env_prompt: '({name}) '" >> "${CONDA_PREFIX}/.condarc"
    echo "solver: libmamba" >> "${CONDA_PREFIX}/.condarc"

    # Reactivate to pick up changes
    conda deactivate
    conda activate "${fullenv}"

    # Copy logo files
    cp "${scriptdir}"/logo*.png "${CONDA_PREFIX}/"
else
    echo "Activating environment \"${fullenv}\""
    conda activate "${fullenv}"
    conda env list
fi

# Install conda packages.
conda_pkgs=""
while IFS='' read -r line || [[ -n "${line}" ]]; do
    # Is this line commented?
    comment=$(echo "${line}" | cut -c 1)
    if [ "${comment}" != "#" ]; then
        pkgname="${line}"
        if [ "${pkgname}" = "python" ]; then
            pkgname="${pkgname}=${version}"
        fi
        conda_pkgs="${conda_pkgs} ${pkgname}"
        num_pkgs=`wc -w <<< $conda_pkgs`
        if [ "${num_pkgs}" = 10 ]; then
            conda install --yes $conda_pkgs
            conda_pkgs=""
        fi
    fi
done < "${scriptdir}/della/packages_conda.txt"

echo "Installing conda packages..."
conda install --yes ${conda_pkgs}
# The "cc" symlink from the compilers package shadows Cray's MPI C compiler...
rm -f "${CONDA_PREFIX}/bin/cc"

conda deactivate
conda activate "${fullenv}"

# Use pipgrip to install dependencies of pip packages with conda.
pip install pipgrip

mkdir -p "${CONDA_PREFIX}/conda-bld"
conda-index "${CONDA_PREFIX}/conda-bld"
conda config \
    --file "${CONDA_PREFIX}/.condarc" \
    --add channels "file://${CONDA_PREFIX}/conda-bld"

# Get the python site packages version
pyver=$(python3 --version 2>&1 | awk '{print $2}' | sed -e "s#\(.*\)\.\(.*\)\..*#\1.\2#")

# Install mpi4py
echo "Building mpi4py with MPICC=\"${MPICC}\""
pip install --force-reinstall --no-cache-dir --no-binary=mpi4py mpi4py

# Build local packages

while IFS='' read -r line || [[ -n "${line}" ]]; do
    # Is this line commented?
    comment=$(echo "${line}" | cut -c 1)
    if [ "${comment}" != "#" ]; then
        pkgname="${line}"
        pkgrecipe="${scriptdir}/pkgs/${pkgname}"
        echo "Building local package '${pkgname}'"
        conda-build ${pkgrecipe} > "log_${pkgname}" 2>&1
        cat "log_${pkgname}"
        echo "Installing local package '${pkgname}'"
        conda install --yes --use-local ${pkgname}
    fi
done < "${scriptdir}/della/packages_local.txt"

echo "Cleaning up build products"
conda-build purge

# Install pip packages.  We install one package at a time
# with no dependencies, so that we will intentionally
# get an error.  All dependency packages should be installed
# through conda.

echo "Installing pip packages..."

while IFS='' read -r line || [[ -n "${line}" ]]; do
    conda deactivate
    conda activate ${fullenv}
    # Is this line commented?
    comment=$(echo "${line}" | cut -c 1)
    if [ "${comment}" != "#" ]; then
        pkg="${line}"
        url_check=$(echo "${pkg}" | grep '/')
        if [ "x${url_check}" = "x" ]; then
            echo "Checking dependencies for package \"${pkg}\""
            for dep in $(pipgrip --pipe ${pkg}); do
                name=$(echo ${dep} | sed -e 's/\([[:alnum:]_\-]*\).*/\1/')
                if [ "${name}" != "${pkg}" ]; then
                    depcheck=$(conda list ${name} | awk '{print $1}' | grep -E "^${name}\$")
                    if [ "x${depcheck}" = "x" ]; then
                        # It is not already installed, try to install it with conda
                        echo "Attempt to install conda package for dependency \"${name}\"..." 
                        conda install --yes ${name}
                        if [ $? -ne 0 ]; then
                            echo "  No conda package available for dependency \"${name}\"" 
                            echo "  Assuming pip package already installed."
                        fi
                    else
                        echo "  Package for dependency \"${name}\" already installed" 
                    fi
                fi
            done
        fi
        echo "Installing package ${pkg}"
        pip install --no-deps ${pkg}
    fi
done < "${scriptdir}/della/packages_pip.txt"

# Create and install module file and jupyter init script
#
#if [ -z "${moduledir}" ]; then
#    # No centralized directory was specified for modulefiles.  Make
#    # a subdirectory within the environment itself.
#    moduledir="${CONDA_PREFIX}/modulefiles"
#fi
#mkdir -p "${moduledir}/${envroot}"
#if [ -z "${LMOD_VERSION}" ]; then
#    # Using TCL modules
#    input_mod="${scriptdir}/templates/modulefile_tcl.in"
#    outmod="${moduledir}/${envroot}/${version}"
#else
#    # Using LMOD
#    input_mod="${scriptdir}/templates/modulefile_lua.in"
#    outmod="${moduledir}/${envroot}/${version}.lua"
#fi
#rm -f "${outmod}"
#
#confsub="-e 's#@VERSION@#${version}#g'"
#confsub="${confsub} -e 's#@BASE@#${conda_dir}#g'"
#confsub="${confsub} -e 's#@ENVNAME@#${fullenv}#g'"
#confsub="${confsub} -e 's#@ENVPREFIX@#${CONDA_PREFIX}#g'"
#confsub="${confsub} -e 's#@PYVER@#${pyver}#g'"
#
#while IFS='' read -r line || [[ -n "${line}" ]]; do
#    if [[ "${line}" =~ @MODLOAD@ ]]; then
#        if [ -e "${modinit}" ]; then
#            cat "${modinit}" >> "${outmod}"
#        fi
#    else
#        echo "${line}" | eval sed ${confsub} >> "${outmod}"
#    fi
#done < "${input_mod}"