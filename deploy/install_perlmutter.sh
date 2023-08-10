#!/bin/bash

#========== Configuration ==================

# Location for conda base
base_dir=/global/common/software/sobs/perlmutter/conda

# Location for temp clones
temp_dir=${SCRATCH}/temp_soconda

# Location for installs
install_dir=/global/common/software/sobs/perlmutter/conda_envs

# Module file directory
module_dir=/global/common/software/sobs/perlmutter/modulefiles

#===========================================

version=$1
if [ "x${version}" = "x" ]; then
    echo "usage:  $0 <soconda branch/tag/hash>"
    exit 1
fi

# Location for clone repos
mkdir -p "${temp_dir}"
today=$(date +%Y%m%d)

# The name of env
env_name="${install_dir}/soconda"

# The full version
env_version="${today}_${version}"

# Clone location
clone_dir="${temp_dir}/${env_version}"

# Make sure the module dir exists
mkdir -p "${module_dir}"

# Log file
logfile="${temp_dir}/log_${env_version}"
echo "Starting at $(date)" > "${logfile}"

# Get specified commit
echo "Making shallow clone of ${version} in ${clone_dir}" >> "${logfile}"

if [ -d "${clone_dir}" ]; then
    rm -rf "${clone_dir}"
fi

git clone --depth=1 --single-branch --branch=${version} https://github.com/tskisner/soconda.git "${clone_dir}" >> "${logfile}" 2>&1

# Activate the base environment
source "${base_dir}/etc/profile.d/conda.sh"
conda activate base >> "${logfile}" 2>&1

# Build things from the temp directory

pushd "${clone_dir}" 2>&1 >/dev/null
mkdir -p "build"
pushd "build" 2>&1 >/dev/null

export MPICC="cc"

eval "${clone_dir}/soconda.sh" \
    -e "${env_name}" \
    -v "${env_version}" \
    -m "${module_dir}" \
    -i "${clone_dir}/deploy/init_nersc_lmod" >> "${logfile}" 2>&1

popd 2>&1 >/dev/null
popd 2>&1 >/dev/null

# Update permissions
chmod -R g-w,g+rX "${env_name}_${env_version}" >> "${logfile}" 2>&1
chmod -R g-w,g+rX "${module_dir}/soconda/*" >> "${logfile}" 2>&1

