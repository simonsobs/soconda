#!/usr/bin/bash
# Install packages to an activated conda environment.

# Location of this script
pushd $(dirname $0) >/dev/null 2>&1
scriptdir=$(pwd)
popd >/dev/null 2>&1

# Make sure conda environment is activated
if [ -z "${CONDA_PREFIX}" ]; then
    echo "Please activate an conda environment"
    exit 1
fi


if [ -n "${CONDA_EXE}" ]; then
    echo "Find conda command at ${CONDA_EXE}"
elif [ -n "${MAMBA_EXE}" ]; then
    echo "Find micromamba command at ${MAMBA_EXE}"
    # micromamba installation does not set CONDA_EXE
    CONDA_EXE="${MAMBA_EXE}"
    eval "$("$MAMBA_EXE" shell hook --shell bash)"
else
    echo "Could not find conda or micromamba command."
    exit 1
fi


# List all environments also show current activated environment
"$CONDA_EXE" env list


# Create ${CONDA_PREFIX}/.condarc if not exist
if [ ! -f "${CONDA_PREFIX}/.condarc" ]; then
    echo "# condarc for soconda" > "${CONDA_PREFIX}/.condarc"
    echo "channels:" >> "${CONDA_PREFIX}/.condarc"
    echo "  - conda-forge" >> "${CONDA_PREFIX}/.condarc"
    echo "  - nodefaults" >> "${CONDA_PREFIX}/.condarc"
    echo "changeps1: true" >> "${CONDA_PREFIX}/.condarc"
    echo "env_prompt: '({name}) '" >> "${CONDA_PREFIX}/.condarc"
    echo "solver: libmamba" >> "${CONDA_PREFIX}/.condarc"
fi

# Set up local build environment
mkdir -p "${CONDA_PREFIX}/conda-bld"
conda index  "${CONDA_PREFIX}/conda-bld"
conda config --file "${CONDA_PREFIX}/.condarc" \
             --prepend channels "file://${CONDA_PREFIX}/conda-bld"


# Install conda packages.
echo "Installing conda packages..." | tee "log_conda"
# For micromamba installation, conda command is not provided.
"$CONDA_EXE" install -p "${CONDA_PREFIX}" --yes --file "${scriptdir}/packages_conda.txt" \
    | tee -a "log_conda" 2>&1
# The "cc" symlink from the compilers package shadows Cray's MPI C compiler...
rm -f "${CONDA_PREFIX}/bin/cc"


# For micromamba installation, conda command is availabe in current environment now.
# For conda installation, reactivate to use conda command from current environment not base environment.
if [ -z "${MAMBA_EXE}" ]; then
    env_path=${CONDA_PREFIX}
    conda deactivate
    conda activate "${env_path}"
fi


# Print something helps debugging
echo ""
echo "CONDA_EXE=${CONDA_EXE}"
echo "CONDA_PREFIX=${CONDA_PREFIX}"
echo "which conda:    $(which conda)"
echo "which python:   $(which python)"
echo "which pip:      $(which pip)"
echo ""


# Use pipgrip to install dependencies of pip packages with conda.
pip install pipgrip


# Install mpi4py
echo "Installing mpi4py..." | tee "log_mpi4py"
if [ -z "${MPICC}" ]; then
    echo "The MPICC environment variable is not set.  Installing mpi4py" \
        | tee -a "log_mpi4py"
    echo "from the conda package, rather than building from source." \
        | tee -a "log_mpi4py"
    conda install --yes mpich mpi4py | tee -a "log_mpi4py" 2>&1
else
    echo "Building mpi4py with MPICC=\"${MPICC}\"" | tee -a "log_mpi4py"
    pip install --force-reinstall --no-cache-dir --no-binary=mpi4py mpi4py \
        | tee -a "log_mpi4py" 2>&1
fi


# Build local packages
while IFS='' read -r line || [[ -n "${line}" ]]; do
    # Is this line commented?
    comment=$(echo "${line}" | cut -c 1)
    if [ "${comment}" != "#" ]; then
        pkgname="${line}"
        pkgrecipe="${scriptdir}/pkgs/${pkgname}"
        echo "Building local package '${pkgname}'"
        conda build ${pkgrecipe} 2>&1 | tee -a "log_${pkgname}"
        echo "Installing local package '${pkgname}'"
        conda install --yes --use-local ${pkgname}
    fi
done < "${scriptdir}/packages_local.txt"

echo "Cleaning up build products"
conda build purge


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
        url_check=$(echo "${pkg}" | grep '/')
        if [ -z "${url_check}" ]; then
            echo "Checking dependencies for package \"${pkg}\""
            for dep in $(pipgrip --pipe ${pkg}); do
                name=$(echo ${dep} | sed -e 's/\([[:alnum:]_\-]*\).*/\1/')
                if [ "${name}" != "${pkg}" ]; then
                    depcheck=$(conda list ${name} | awk '{print $1}' | grep -E "^${name}\$")
                    if [ -z "${depcheck}" ]; then
                        # It is not already installed, try to install it with conda
                        echo "Attempt to install conda package for dependency \"${name}\"..." | tee -a "log_pip" 2>&1
                        conda install --yes ${name} | tee -a "log_pip" 2>&1
                        if [ $? -ne 0 ]; then
                            echo "  No conda package available for dependency \"${name}\"" | tee -a "log_pip" 2>&1
			    echo "  Assuming pip package already installed." | tee -a "log_pip" 2>&1
                        fi
                    else
                        echo "  Package for dependency \"${name}\" already installed" | tee -a "log_pip" 2>&1
                    fi
                fi
            done
        fi
        echo "Installing package ${pkg}"
        python3 -m pip install --no-deps ${pkg} | tee -a "log_pip" 2>&1
    fi
done < "${scriptdir}/packages_pip.txt"
