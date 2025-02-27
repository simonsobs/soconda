#!/bin/bash

# Location of this script
pushd $(dirname $0) 2>&1 >/dev/null
scriptdir=$(pwd)
popd 2>&1 >/dev/null

show_help () {
    echo "" >&2
    echo "Usage:  $0" >&2
    echo "    [-c <directory in config to use for options>]" >&2
    echo "    [-e <environment, either name or full path>]" >&2
    echo "    [-b <conda base install (if not activated)>]" >&2
    echo "    [-v <version (git version used by default)>]" >&2
    echo "    [-m <modulefile dir (default is <env>/modulefiles)>]" >&2
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

while getopts ":e:c:b:v:m:" opt; do
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
if [ "${envname}" = "base" ]; then
    # We are installing directly to the base conda env.  This is normally
    # a bad idea, but sometimes makes sense (e.g. inside a docker
    # container).
    fullenv="base"
else
    fullenv="${envname}_${version}"
fi
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

# Load any module that the installation might need.
if [ -e "${confdir}/required_modules.txt" ]; then
    while IFS= read -r line
    do
        module load "$line"
    done < "${confdir}/required_modules.txt"
fi

is_micromamba='no'
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
        echo "Found conda command at ${CONDA_EXE}"
        conda_dir="$(dirname $(dirname $CONDA_EXE))"
        # Initialize conda
        eval "$("$CONDA_EXE" 'shell.bash' 'hook')"
        conda_exec () { conda "$@" ; }
    elif [ -n "$MAMBA_EXE" ]; then
        # If both $CONDA_EXE and $MAMBA_EXE variables are defined,
        # $CONDA_EXE will take precedence.
        echo "Found micromamba command at ${MAMBA_EXE}"
        conda_dir="$MAMBA_ROOT_PREFIX"
        # Initialize micromamba
        eval "$("$MAMBA_EXE" shell hook --shell bash)"
        conda_exec () { micromamba "$@" ; }
        is_micromamba='yes'
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
        # MacOS mktemp has different arguments.  This is portable.
        conda_tmp=$(mktemp -d "$scriptdir/tmpfs/conda_pkgs.XXXXXX")
        export TMPDIR="$conda_tmp"
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

# Get just the major and minor version to use when specifying the
# python build variant during package build.
python_major_minor=$(echo ${python_version} | sed -E 's/python=(3\.[[:digit:]]+).*/\1/')

# Check if this env exists or not.
# env_check would be empty if it does not exist.
env_check=$(conda_exec env list | grep "${fullenv}")
echo -e "\n\n"
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

    # If we are using micromamba (not just mamba), then there is no
    # base environment.  In that case, install conda build tools directly.
    # Note that conda-forge environments now ship with the `mamba` executable.
    if [ "${is_micromamba}" = "yes" ]; then
        # Install conda packages to micromamba env
        conda_exec install --yes conda conda-build conda-index
        # In the remaining part of code, unless activating/switching
        # environment and installing packages, we all use `conda` command.
        # This is due to there is no `micromamba index` or `micromamba build`
        # command.
    fi

    # Create condarc for this environment.  Note: The conda build
    # tools are installed in the base environment and so the
    # "--use-local" option will not let us find the built packages
    # we will store inside this env.  Because of this, we create a
    # package directory in our environment and add it to the
    # condarc.
    mkdir -p "${CONDA_PREFIX}/conda-bld"
    mkdir -p "${CONDA_PREFIX}/conda-bld/temp_build"
    conda index "${CONDA_PREFIX}/conda-bld"

    echo "# condarc for soconda" > "${CONDA_PREFIX}/.condarc"
    echo "channels:" >> "${CONDA_PREFIX}/.condarc"
    echo "  - file://${CONDA_PREFIX}/conda-bld" >> "${CONDA_PREFIX}/.condarc"
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
    # Ensure that the build folder is added to the channel list
    conda config --env --add channels "file://${CONDA_PREFIX}/conda-bld"
fi
conda_exec env list

# Build local packages.  These are built in an isolated environment with
# all dependencies installed from upstream or our local $CONDA_PREFIX/conda-bld.
# The conda executable and its plugins (conda-build, conda-verify, etc)
# are always kept in the base environment.

export CONDA_BLD_PATH="${CONDA_PREFIX}/conda-bld"

local_pkgs=""
while IFS='' read -r line || [[ -n "${line}" ]]; do
    # Is this line commented?
    comment=$(echo "${line}" | cut -c 1)
    if [ "${comment}" != "#" ]; then
        pkgname="${line}"
        pkgrecipe="${scriptdir}/pkgs/${pkgname}"
        local_pkgs="${local_pkgs} ${pkgname}"
        echo -e "\n\n"
        echo "Building local package '${pkgname}'" 2>&1 | tee "log_${pkgname}"
        conda build \
            --variants "{'python':['${python_major_minor}']}" \
            --numpy 2.1 \
            ${pkgrecipe} 2>&1 | tee -a "log_${pkgname}"
    fi
done < "${confdir}/packages_local.txt"

echo -e "\n\n"
echo "Cleaning up build products"
rm -rf "${CONDA_PREFIX}/conda-bld/temp_build"

# Remove temporary package directory
rm -rf "${conda_tmp}" &> /dev/null

# Remove /tmp/pixell-* test files create by pixell/setup.py
find "/tmp" -maxdepth 1 -type f -name 'pixell-*' -exec rm {} \;


# Install upstream conda packages.
echo -e "\n\n"
echo "Installing conda packages..." | tee "log_conda"
conda_exec install --yes \
    --file "${scriptdir}/config/common.txt" \
    --file "${confdir}/packages_conda.txt" \
    2>&1 | tee -a "log_conda"

conda_exec deactivate
conda_exec activate "${fullenv}"

# Install local conda packages.
echo -e "\n\n"
echo "Installing local packages..." | tee -a "log_conda"
conda_exec install --yes ${local_pkgs} \
    2>&1 | tee -a "log_conda"

conda_exec deactivate
conda_exec activate "${fullenv}"


# Install mpi4py
echo -e "\n\n"
echo "Installing mpi4py..." | tee "log_mpi4py"
if [ -z "${MPICC}" ]; then
    echo "The MPICC environment variable is not set.  Installing mpi4py" \
        | tee -a "log_mpi4py"
    echo "from the conda package, rather than building from source." \
        | tee -a "log_mpi4py"
    conda_exec install --yes openmpi mpi4py 2>&1 | tee -a "log_mpi4py"
    # Disable the ancient openib btl, in order to avoid a harmless warning
    echo 'btl = ^openib' >> "${CONDA_PREFIX}/etc/openmpi-mca-params.conf"
else
    echo "Building mpi4py with MPICC=\"${MPICC}\"" | tee -a "log_mpi4py"
    pip install --force-reinstall --no-cache-dir --no-binary=mpi4py mpi4py \
        2>&1 | tee -a "log_mpi4py"
fi


# Install pip packages.  We install one package at a time
# with no dependencies, so that we will intentionally
# get an error.  All dependency packages should be installed
# through conda.

# Use pipgrip to install dependencies of pip packages with conda.
echo -e "\n\n"
pip install pipgrip

echo -e "\n"
echo "Installing pip packages..." | tee "log_pip"

installed_pkgs="$(conda_exec list | awk '{print $1}')"
while IFS='' read -r line || [[ -n "${line}" ]]; do
    # Skip if $line is empty
    # If the $line start with '#' then it's a comment.
    if [[ -n "${line}" && "${line:0:1}" != "#" ]]; then
        pkg="${line}"
        url_check=$(echo "${pkg}" | grep '/')
        if [ -z "${url_check}" ]; then
            echo "Checking dependencies for package \"${pkg}\"" 2>&1 | tee -a "log_pip"
            pkgbase=$(echo ${pkg} | sed -e 's/\([[:alnum:]_\-]*\).*/\1/')
            for dep in $(pipgrip --pipe --threads 4 "${pkg}"); do
                name=$(echo ${dep} | sed -e 's/\([[:alnum:]_\-]*\).*/\1/')
                if [ "${name}" != "${pkgbase}" ]; then
                    depcheck=$(echo "$installed_pkgs" | grep -E "^${name}\$")
                    if [ -z "${depcheck}" ]; then
                        # It is not already installed, try to install it with conda
                        echo "Attempt to install conda package for dependency \
                        \"${name}\"..." 2>&1 | tee -a "log_pip"
                        conda_exec install --yes ${name} 2>&1 | tee -a "log_pip"
                        installed_pkgs="${installed_pkgs}"$'\n'"${name}"
                    else
                        echo "  Package for dependency \"${name}\" already installed" \
                        2>&1 | tee -a "log_pip"
                    fi
                fi
            done
        else
            echo "Pip package \"${pkg}\" is a URL, skipping dependency check" \
            2>&1 | tee -a "log_pip"
        fi
        echo "Installing package ${pkg} with --no-deps" 2>&1 | tee -a "log_pip"
        python3 -m pip install --no-deps ${pkg} 2>&1 | tee -a "log_pip"
        installed_pkgs="${installed_pkgs}"$'\n'"${pkg}"
        echo -e "\n\n"
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

# Clean up
conda clean --all --yes
