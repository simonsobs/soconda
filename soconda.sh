#!/bin/bash

# Location of this script
pushd $(dirname $0) >/dev/null 2>&1
scriptdir=$(pwd)
popd >/dev/null 2>&1

show_help () {
    echo "" >&2
    echo "Usage:  $0" >&2
    echo "    -e <environment, either name or full path>" >&2
    echo "    [-b <conda base install (if not activated)>]" >&2
    echo "    [-v <version (git version used by default)>]" >&2
    echo "    [-m <modulefile dir (env/modulefiles used by default)>]" >&2
    echo "" >&2
    echo "    Create a conda environment for Simons Observatory." >&2
    echo "" >&2
    echo "" >&2
}

base=""
envname=""
version=""
moduledir=""

while getopts ":e:b:v:m:" opt; do
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

if [ "x${envname}" == "x" ]; then
    echo "You must specify the environment name or path"
    show_help
    exit 1
fi

if [ "x${version}" == "x" ]; then
    # Get the version from git
    gitdesc=$(git describe --tags --dirty --always | cut -d "-" -f 1)
    gitcnt=$(git rev-list --count HEAD)
    version="${gitdesc}.dev${gitcnt}"
fi

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
env_noslash=$(echo "${envname}" | sed -e 's/\///g')
is_path=no
if [ "${env_noslash}" != "${envname}" ]; then
    # This was a path
    is_path=yes
    env_check=""
    if [ -e "${envname}/bin/conda" ]; then
	    # It already exists
	    env_check="${envname}"
    fi
else
    env_check=$(conda env list | grep "${envname} ")
fi

if [ "x${env_check}" = "x" ]; then
    # Environment does not yet exist.  Create it.
    if [ ${is_path} = "no" ]; then
	    echo "Creating new environment \"${envname}\""
	    conda create --yes -n "${envname}"
    else
	    echo "Creating new environment \"${envname}\""
	    conda create --yes -p "${envname}"
    fi
    echo "Activating environment \"${envname}\""
    conda activate "${envname}"
    echo "Setting default channel in this env to conda-forge"
    conda config --env --add channels conda-forge
    conda config --env --set channel_priority strict
else
    echo "Activating environment \"${envname}\""
    conda activate "${envname}"
    conda env list
fi

# Install conda packages

echo "Installing conda packages..."
conda install --yes --update-all --file "${scriptdir}/packages_conda.txt"
# The "cc" symlink from the compilers package shadows Cray's MPI C compiler...
rm -f "${CONDA_PREFIX}/bin/cc"

# Has the user set MPICC to something?
if [ "x${MPICC}" = "x" ]; then
    echo "The MPICC environment variable is not set.  Installing mpi4py"
    echo "from the conda package, rather than building from source."
    conda install --yes mpich mpi4py
else
    echo "Building mpi4py with MPICC=\"${MPICC}\""
    pip install --force-reinstall --no-cache-dir --no-binary=mpi4py mpi4py
fi

# Install compiled packages

# while IFS='' read -r line || [[ -n "${line}" ]]; do
#     # Is this line commented?
#     comment=$(echo "${line}" | cut -c 1)
#     if [ "${comment}" != "#" ]; then
#         pkgname="${line}"
#         pkgscript="${scriptdir}/pkgs/${pkgname}.sh"
#         echo "Building package ${pkgname}"
#         eval "${pkgscript}" 2>&1 | tee "log_${pkgname}"
#     fi
# done < "${scriptdir}/packages_compiled.txt"

# Install pip packages

pip install -r "${scriptdir}/packages_pip.txt"
