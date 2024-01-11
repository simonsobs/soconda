#!/bin/bash

# Location of this script
pushd $(dirname $0) >/dev/null 2>&1
scriptdir=$(pwd)
popd >/dev/null 2>&1

show_help () {
    echo "" >&2
    echo "Usage:  $0" >&2
    echo "    [-c <directory in config to use for options>]" >&2
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
config=""
version=""
moduledir=""
modinit=""

while getopts ":e:c:b:v:m:i:" opt; do
    case $opt in
        e)
            envname=$OPTARG
            ;;
        b)
            base=$OPTARG
            ;;
        c)
            config=$OPTARG
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

if [ -z "${version}" ]; then
    # Get the version from git
    gitdesc=$(git describe --tags --dirty --always | cut -d "-" -f 1)
    gitcnt=$(git rev-list --count HEAD)
    version="${gitdesc}.dev${gitcnt}"
fi

if [ -z "${envname}" ]; then
    echo "Environment root name not specified, using \"soconda\""
    envname="soconda"
fi
# The full environment name, including the root and version.
fullenv="${envname}_${version}"
# Determine whether the new environment is a name or a full path.
env_noslash=$(echo "${fullenv}" | sed -e 's/\///g')
if [ "${env_noslash}" != "${fullenv}" ]; then
    # This was a path
    is_path='yes'
    # Make sure this is a full path
    if [[ "${envname:0:1}" != '/' ]] ; then
        # The path does not start at root
        echo "Please provide a full path."
        exit 1
    fi
else
    is_path='no'
fi


if [ -z "${config}" ]; then
    echo "No config specified, using \"default\""
    config="default"
else
    echo "Using config \"${config}\""
fi

# The path to the selected config directory
confdir="${scriptdir}/config/${config}"
if [ ! -d "${confdir}" ]; then
    echo "Config dir \"${confdir}\" does not exist"
    exit 1
fi


if [ -n "${base}" ]; then
    conda_dir="${base}"
    # Initialize conda
    source "${conda_dir}/etc/profile.d/conda.sh"
    # Conda initialization script will create conda function,
    # but micromamba will create micromamba function.
    # Here create a conda_exec function that unify conda and micromamba
    # installation.
    conda_exec () { conda "$@" ; }
else
    # User did not specify where to find it
    if [ -n "$CONDA_EXE" ]; then
        echo "Find conda command at ${CONDA_EXE}"
        conda_dir="$(dirname $(dirname $CONDA_EXE))"
        # Initialize conda
        eval "$("$CONDA_EXE" 'shell.bash' 'hook')"
        conda_exec () { conda "$@" ; }
    elif [ -n "$MAMBA_EXE" ]; then
        echo "Find micromamba command at ${MAMBA_EXE}"
        conda_dir="$MAMBA_ROOT_PREFIX"
        # Initialize micromamba
        eval "$("$MAMBA_EXE" shell hook --shell bash)"
        conda_exec () { micromamba "$@" ; }
    else
        # Could not find conda or micromamba
        echo "You must either activate the conda base environment before"
        echo "running this script, or you must specify the path to the base"
        echo "install with the \"-b <path to base>\" option."
        exit 1
    fi
fi


# Conda package cache.  In some cases this can get really big, so
# we point it to a temp location unless the user has overridden it.
if [ -z ${CONDA_PKGS_DIRS} ]; then
    if [ -z ${NERSC_HOST} ]; then
        # Standard system
        # Create temp direcotry
        mkdir -p "$scriptdir/tmpfs"
        conda_tmp=$(mktemp -d --tmpdir="$scriptdir/tmpfs")
    else
        # Running at NERSC, use a directory in scratch
        conda_tmp="${SCRATCH}/tmp_soconda"
        mkdir -p "${conda_tmp}"
    fi
    export CONDA_PKGS_DIRS="${conda_tmp}"
fi


# Extract the python version we are using (if not the default)
# and pass that to the conda create command.
python_version=$(cat "${confdir}/packages_conda.txt" | grep 'python=')

# Check this env exist or not
# env_check would be empty if not exist
env_check=$(conda_exec env list | grep "${fullenv}")
if [ -z "${env_check}" ]; then
    if [ ${is_path} = "no" ]; then
        echo "Creating new environment \"${fullenv}\""
        conda_exec create --yes -n "${fullenv}" "${python_version}"
    else
        echo "Creating new environment \"${fullenv}\""
        conda_exec create --yes -p "${fullenv}" "${python_version}"
    fi
    echo "Activating environment \"${fullenv}\""
    conda_exec activate "${fullenv}"

    # Create condarc for this environment
    echo "# condarc for soconda" > "${CONDA_PREFIX}/.condarc"
    echo "channels:" >> "${CONDA_PREFIX}/.condarc"
    echo "  - conda-forge" >> "${CONDA_PREFIX}/.condarc"
    echo "  - nodefaults" >> "${CONDA_PREFIX}/.condarc"
    echo "changeps1: true" >> "${CONDA_PREFIX}/.condarc"
    echo "env_prompt: '({name}) '" >> "${CONDA_PREFIX}/.condarc"
    echo "solver: libmamba" >> "${CONDA_PREFIX}/.condarc"

    # Reactivate to pick up changes
    conda_exec deactivate
    conda_exec activate "${fullenv}"

    # Copy logo files
    cp "${scriptdir}"/logo* "${CONDA_PREFIX}/"
else
    echo "Activating environment \"${fullenv}\""
    conda_exec activate "${fullenv}"
fi
conda_exec env list


# Install conda packages.
echo "Installing conda packages..." | tee "log_conda"
conda_exec install --yes --file "${scriptdir}/config/common.txt" \
    | tee -a "log_conda" 2>&1
conda_exec install --yes --file "${confdir}/packages_conda.txt" \
    | tee -a "log_conda" 2>&1
# The "cc" symlink from the compilers package shadows Cray's MPI C compiler...
rm -f "${CONDA_PREFIX}/bin/cc"

conda_exec deactivate
conda_exec activate "${fullenv}"


# Install mpi4py
echo "Installing mpi4py..." | tee "log_mpi4py"
if [ -z "${MPICC}" ]; then
    echo "The MPICC environment variable is not set.  Installing mpi4py" \
        | tee -a "log_mpi4py"
    echo "from the conda package, rather than building from source." \
        | tee -a "log_mpi4py"
    conda_exec install --yes openmpi mpi4py | tee -a "log_mpi4py" 2>&1 \
    # Disable the ancient openib btl, in order to avoid a harmless warning
    echo 'btl = ^openib' >> "${CONDA_PREFIX}/etc/openmpi-mca-params.conf"
else
    echo "Building mpi4py with MPICC=\"${MPICC}\"" | tee -a "log_mpi4py"
    pip install --force-reinstall --no-cache-dir --no-binary=mpi4py mpi4py \
        | tee -a "log_mpi4py" 2>&1
fi


# Build local packages
# Here we use conda instead of conda_exec, because conda is a dependency
# of conda-build package. Therefore after activated ${fullenv},
# conda command is availabe in both micromamba and miniforge installation.
# If you run $(which conda) command it should return $CONDA_PREFIX/bin/conda
# in both cases.
mkdir -p "${CONDA_PREFIX}/conda-bld"
conda index "${CONDA_PREFIX}/conda-bld"
conda config \
    --file "${CONDA_PREFIX}/.condarc" \
    --add channels "file://${CONDA_PREFIX}/conda-bld"

while IFS='' read -r line || [[ -n "${line}" ]]; do
    # Is this line commented?
    comment=$(echo "${line}" | cut -c 1)
    if [ "${comment}" != "#" ]; then
        pkgname="${line}"
        pkgrecipe="${scriptdir}/pkgs/${pkgname}"
        echo "Building local package '${pkgname}'" | tee "log_${pkgname}" 2>&1
        conda build ${pkgrecipe} | tee -a "log_${pkgname}" 2>&1
        echo "Installing local package '${pkgname}'" | tee -a "log_${pkgname}" 2>&1
        conda install --yes --use-local ${pkgname} | tee -a "log_${pkgname}" 2>&1
    fi
done < "${confdir}/packages_local.txt"

echo "Cleaning up build products"
conda build purge

# Remove buid directory
rm -rf "${conda_tmp}" &> /dev/null

# Remove /tmp/pixell-* test files create by pixell/setup.py
find /tmp -maxdepth 1 -type f -name 'pixell-*' -exec ls {} \;


# Install pip packages.  We install one package at a time
# with no dependencies, so that we will intentionally
# get an error.  All dependency packages should be installed
# through conda.

# Use pipgrip to install dependencies of pip packages with conda.
pip install pipgrip

echo "Installing pip packages..." | tee "log_pip"

while IFS='' read -r line || [[ -n "${line}" ]]; do
    # If the $line start with '#' then it's a comment.
    if [ "${line:0:1}" != "#" ]; then
        pkg="${line}"
        url_check=$(echo "${pkg}" | grep '/')
        if [ -z "${url_check}" ]; then
            echo "Checking dependencies for package \"${pkg}\"" | tee -a "log_pip" 2>&1
            pkgbase=$(echo ${pkg} | sed -e 's/\([[:alnum:]_\-]*\).*/\1/')
            for dep in $(pipgrip --pipe "${pkg}"); do
                name=$(echo ${dep} | sed -e 's/\([[:alnum:]_\-]*\).*/\1/')
                if [ "${name}" != "${pkgbase}" ]; then
                    depcheck=$(conda list ${name} | awk '{print $1}' | grep -E "^${name}\$")
                    if [ -z "${depcheck}" ]; then
                        # It is not already installed, try to install it with conda
                        echo "Attempt to install conda package for dependency \"${name}\"..." | tee -a "log_pip" 2>&1
                        conda_exec install --yes ${name} | tee -a "log_pip" 2>&1
                        if [ $? -ne 0 ]; then
                            echo "  No conda package available for dependency \"${name}\"" | tee -a "log_pip" 2>&1
                            echo "  Assuming pip package already installed." | tee -a "log_pip" 2>&1
                        fi
                    else
                        echo "  Package for dependency \"${name}\" already installed" | tee -a "log_pip" 2>&1
                    fi
                fi
            done
        else
            echo "Pip package \"${pkg}\" is a URL, skipping dependency check" | tee -a "log_pip" 2>&1
        fi
        echo "Installing package ${pkg} with --no-deps" | tee -a "log_pip" 2>&1
        python3 -m pip install --no-deps ${pkg} | tee -a "log_pip" 2>&1
    fi
done < "${confdir}/packages_pip.txt"


# Get the python site packages version
pyver=$(python3 --version 2>&1 | awk '{print $2}' | sed -e "s#\(.*\)\.\(.*\)\..*#\1.\2#")

# Subsitutions to use when parsing input templates
confsub="-e 's#@VERSION@#${version}#g'"
confsub="${confsub} -e 's#@BASE@#${conda_dir}#g'"
confsub="${confsub} -e 's#@ENVNAME@#${fullenv}#g'"
confsub="${confsub} -e 's#@ENVPREFIX@#${CONDA_PREFIX}#g'"
confsub="${confsub} -e 's#@PYVER@#${pyver}#g'"

# Source post-install options, if they exist
if [ -e "${confdir}/post_install.sh" ]; then
    source "${confdir}/post_install.sh"
fi

# If the option is enabled in post_install.sh, install modulefile
if [ -n "${install_module}" ]; then
    source "${scriptdir}/tools/install_modulefile.sh"
fi

# If the option is enabled in post_install.sh install jupyter setup
if [ -n "${install_jupyter_setup}" ]; then
    source "${scriptdir}/tools/install_jupyter_setup.sh"
fi
