#!/bin/bash

# Location of this script
pushd $(dirname $0) >/dev/null 2>&1
scriptdir=$(pwd)
popd >/dev/null 2>&1

show_help () {
    echo "" >&2
    echo "Usage:  $0" >&2
    echo "    [-e <environment, either name or full path>]" >&2
    echo "    [-b <conda base install (if not activated)>]" >&2
    echo "    [-v <version (git version used by default)>]" >&2
    echo "    [-m <modulefile dir (default is <env>/modulefiles)>]" >&2
    echo "    [-i <file with modulefile commands to load dependencies> ]" >&2
    echo "" >&2
    echo "    Create a conda environment for Simons Observatory." >&2
    echo "" >&2
    echo "" >&2
}

base=""
envname=""
version=""
moduledir=""
modinit=""

while getopts ":e:b:v:m:i:" opt; do
    case $opt in
        e)
            envname=$OPTARG
            ;;
        b)
            base=$OPTARG
            ;;
        v)
            version=$OPTARG
            ;;
        m)
            moduledir=$OPTARG
            ;;
        i)
            modinit=$OPTARG
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

if [ "x${version}" = "x" ]; then
    # Get the version from git
    gitdesc=$(git describe --tags --dirty --always | cut -d "-" -f 1)
    gitcnt=$(git rev-list --count HEAD)
    version="${gitdesc}.dev${gitcnt}"
fi

if [ "x${envname}" = "x" ]; then
    echo "Environment root name not specified, using \"soconda\""
    envname="soconda"
fi

# The env root name, used for the name of the generated module file
envroot=$(basename ${envname})

# The full environment name, including the root and version.
fullenv="${envname}_${version}"

# Activate the base environment

if [ "x$(which conda)" = "x" ]; then
    # conda is not in the path
    if [ "x${base}" = "x" ]; then
        # User did not specify where to find it
        echo "You must either activate the conda base environment before"
        echo "running this script, or you must specify the path to the base"
        echo "install with the \"-b <path to base>\" option."
        exit 1
    fi
    conda_dir="${base}"
else
    # Conda is in the path
    conda_dir="$(dirname $(dirname $(which conda)))"
fi

# Make sure that conda is initialized
source "${conda_dir}/etc/profile.d/conda.sh"
conda activate base

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

if [ "x${env_check}" = "x" ]; then
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
    echo "  - file://${CONDA_PREFIX}/conda-bld" >> "${CONDA_PREFIX}/.condarc"
    echo "  - conda-forge" >> "${CONDA_PREFIX}/.condarc"
    echo "channel_priority: strict" >> "${CONDA_PREFIX}/.condarc"
    echo "changeps1: true" >> "${CONDA_PREFIX}/.condarc"
    echo "envs_dirs:" >> "${CONDA_PREFIX}/.condarc"
    echo "  - $(dirname ${CONDA_PREFIX})" >> "${CONDA_PREFIX}/.condarc"
    echo "env_prompt: '({name}) '" >> "${CONDA_PREFIX}/.condarc"

    # Reactivate to pick up changes
    conda deactivate
    conda activate "${fullenv}"

    # Update conda and low-level tools
    conda update --all
else
    echo "Activating environment \"${fullenv}\""
    conda activate "${fullenv}"
    conda env list
fi

# Install conda packages

echo "Installing conda packages..." | tee "log_conda"
conda install --yes --update-all --file "${scriptdir}/packages_conda.txt" \
    2>&1 | tee -a "log_conda"
# The "cc" symlink from the compilers package shadows Cray's MPI C compiler...
rm -f "${CONDA_PREFIX}/bin/cc"

conda deactivate
conda activate "${fullenv}"

# Get the python site packages version
pyver=$(python3 --version 2>&1 | awk '{print $2}' | sed -e "s#\(.*\)\.\(.*\)\..*#\1.\2#")

# Install mpi4py

echo "Installing mpi4py..." | tee "log_mpi4py"
if [ "x${MPICC}" = "x" ]; then
    echo "The MPICC environment variable is not set.  Installing mpi4py" \
        | tee -a "log_mpi4py"
    echo "from the conda package, rather than building from source." \
        | tee -a "log_mpi4py"
    conda install --yes mpich mpi4py 2>&1 | tee -a "log_mpi4py"
else
    echo "Building mpi4py with MPICC=\"${MPICC}\"" | tee -a "log_mpi4py"
    pip install --force-reinstall --no-cache-dir --no-binary=mpi4py mpi4py \
        2>&1 | tee -a "log_mpi4py"
fi

# Install local packages

while IFS='' read -r line || [[ -n "${line}" ]]; do
    # Is this line commented?
    comment=$(echo "${line}" | cut -c 1)
    if [ "${comment}" != "#" ]; then
        pkgname="${line}"
        pkgrecipe="${scriptdir}/pkgs/${pkgname}"
        echo "Building local package '${pkgname}'"
        eval "conda build ${pkgrecipe}" 2>&1 | tee "log_${pkgname}"
        echo "Installing local package '${pkgname}'"
        eval "conda install --yes --use-local ${pkgname}"
	echo "Cleaning up build products"
	eval "conda build purge"
    fi
done < "${scriptdir}/packages_local.txt"

# Install pip packages.  We install one package at a time
# with no dependencies, so that we will intentionally
# get an error.  All dependency packages should be installed
# through conda.

echo "Installing pip packages..." | tee "log_pip"

while IFS='' read -r line || [[ -n "${line}" ]]; do
    # Is this line commented?
    comment=$(echo "${line}" | cut -c 1)
    if [ "${comment}" != "#" ]; then
        pkg="${line}"
        echo "Installing package ${pkg}"
        pip install --no-deps ${pkg} 2>&1 | tee -a "log_pip"
    fi
done < "${scriptdir}/packages_pip.txt"

# Create and install module file

if [ "x${moduledir}" = "x" ]; then
    # No centralized directory was specified for modulefiles.  Make
    # a subdirectory within the environment itself.
    moduledir="${CONDA_PREFIX}/modulefiles"
fi
mkdir -p "${moduledir}/${envroot}"
outmod="${moduledir}/${envroot}/${version}"
rm -f "${outmod}"

confsub="-e 's#@VERSION@#${version}#g'"
confsub="${confsub} -e 's#@BASE@#${conda_dir}#g'"
confsub="${confsub} -e 's#@ENVNAME@#${fullenv}#g'"
confsub="${confsub} -e 's#@ENVPREFIX@#${CONDA_PREFIX}#g'"
confsub="${confsub} -e 's#@PYVER@#${pyver}#g'"

if [ "x${LMOD_VERSION}" = "x" ]; then
    # Using TCL modules
    input_mod="${scriptdir}/templates/modulefile_tcl.in"
else
    # Using LMOD
    input_mod="${scriptdir}/templates/modulefile_lua.in"
fi

while IFS='' read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ @MODLOAD@ ]]; then
        if [ -e "${modinit}" ]; then
            cat "${modinit}" >> "${outmod}"
        fi
    else
        echo "${line}" | eval sed ${confsub} >> "${outmod}"
    fi
done < "${input_mod}"
