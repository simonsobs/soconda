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
    echo "  - conda-forge" >> "${CONDA_PREFIX}/.condarc"
    echo "changeps1: true" >> "${CONDA_PREFIX}/.condarc"
    echo "env_prompt: '({name}) '" >> "${CONDA_PREFIX}/.condarc"

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
        conda_pkgs="${conda_pkgs} ${pkgname}"
    fi
done < "${scriptdir}/packages_conda.txt"

echo "Installing conda packages..." | tee "log_conda"
conda install --yes --update-all ${conda_pkgs} \
    | tee -a "log_conda" 2>&1
# The "cc" symlink from the compilers package shadows Cray's MPI C compiler...
rm -f "${CONDA_PREFIX}/bin/cc"

conda deactivate
conda activate "${fullenv}"

# Install low-level tools, including pipgrip which we
# use to install dependencies of pip packages with conda.
conda install --yes --update-all setuptools pip wheel anytree click packaging
pip install pipgrip

mkdir -p "${CONDA_PREFIX}/conda-bld"
conda-index "${CONDA_PREFIX}/conda-bld"
conda config \
    --file "${CONDA_PREFIX}/.condarc" \
    --add channels "file://${CONDA_PREFIX}/conda-bld"

# Get the python site packages version
pyver=$(python3 --version 2>&1 | awk '{print $2}' | sed -e "s#\(.*\)\.\(.*\)\..*#\1.\2#")

# Install mpi4py

echo "Installing mpi4py..." | tee "log_mpi4py"
if [ "x${MPICC}" = "x" ]; then
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
        conda-build ${pkgrecipe} > "log_${pkgname}" 2>&1
        cat "log_${pkgname}"
        echo "Installing local package '${pkgname}'"
        conda install --yes --use-local ${pkgname}
    fi
done < "${scriptdir}/packages_local.txt"

echo "Cleaning up build products"
conda-build purge

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
        if [ "x${url_check}" = "x" ]; then
            echo "Checking dependencies for package \"${pkg}\""
            for dep in $(pipgrip --pipe ${pkg}); do
                name=$(echo ${dep} | sed -e 's/\([[:alnum:]_\-]*\).*/\1/')
                if [ "${name}" != "${pkg}" ]; then
                    depcheck=$(conda list ${name} | awk '{print $1}' | grep -E "^${name}\$")
                    if [ "x${depcheck}" = "x" ]; then
                        # It is not already installed, try to install it with conda
                        echo "Attempt to install conda package for dependency \"${name}\"..." | tee -a "log_pip" 2>&1
                        conda install --yes ${name} | tee -a "log_pip" 2>&1
                        if [ $? -ne 0 ]; then
                            echo "  No conda package available for dependency \"${name}\"" | tee -a "log_pip" 2>&1
                        fi
                    else
                        echo "  Package for dependency \"${name}\" already installed" | tee -a "log_pip" 2>&1
                    fi
                fi
            done
        fi
        echo "Installing package ${pkg}"
        python3 -m pip install ${pkg} | tee -a "log_pip" 2>&1
    fi
done < "${scriptdir}/packages_pip.txt"

# Create jupyter kernel launcher
kern="${CONDA_PREFIX}/bin/soconda_run_kernel.sh"
echo "#!/bin/bash" > "${kern}"
echo "conn=\$1" >> "${kern}"
echo "source \"${conda_dir}/etc/profile.d/conda.sh\"" >> "${kern}"
echo "conda activate \"${fullenv}\"" >> "${kern}"
echo "export DISABLE_MPI=true" >> "${kern}"
echo "exec python3 -m ipykernel -f \${conn}" >> "${kern}"
chmod +x "${kern}"

# Create and install module file and jupyter init script

if [ "x${moduledir}" = "x" ]; then
    # No centralized directory was specified for modulefiles.  Make
    # a subdirectory within the environment itself.
    moduledir="${CONDA_PREFIX}/modulefiles"
fi
mkdir -p "${moduledir}/${envroot}"
if [ "x${LMOD_VERSION}" = "x" ]; then
    # Using TCL modules
    input_mod="${scriptdir}/templates/modulefile_tcl.in"
    outmod="${moduledir}/${envroot}/${version}"
else
    # Using LMOD
    input_mod="${scriptdir}/templates/modulefile_lua.in"
    outmod="${moduledir}/${envroot}/${version}.lua"
fi
rm -f "${outmod}"

confsub="-e 's#@VERSION@#${version}#g'"
confsub="${confsub} -e 's#@BASE@#${conda_dir}#g'"
confsub="${confsub} -e 's#@ENVNAME@#${fullenv}#g'"
confsub="${confsub} -e 's#@ENVPREFIX@#${CONDA_PREFIX}#g'"
confsub="${confsub} -e 's#@PYVER@#${pyver}#g'"

while IFS='' read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ @MODLOAD@ ]]; then
        if [ -e "${modinit}" ]; then
            cat "${modinit}" >> "${outmod}"
        fi
    else
        echo "${line}" | eval sed ${confsub} >> "${outmod}"
    fi
done < "${input_mod}"

rm -f "${out_jupyter}"
out_jupyter="${CONDA_PREFIX}/bin/soconda_jupyter.sh"
while IFS='' read -r line || [[ -n "${line}" ]]; do
    echo "${line}" | eval sed ${confsub} >> "${out_jupyter}"
done < "${scriptdir}/templates/jupyter.sh.in"
chmod +x "${out_jupyter}"
