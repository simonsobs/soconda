#!/bin/bash

#========== Configuration ==================

# Location for conda base
base_dir=/cephfs/soukdata/software/python/soconda_builds/build_bases

# Location for temp clones
temp_dir=/cephfs/soukdata/software/python/tmp_cepfs

# Location for installs
install_dir=/cephfs/soukdata/software/python/soconda_builds
CONDA_PKGS_DIRS=/cephfs/soukdata/software/python/tmp_conda

# Module file directory
module_dir=/cephfs/soukdata/software/modulefiles

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

git clone --depth=1 --single-branch --branch=${version} https://github.com/josephwkania/soconda.git "${clone_dir}" >> "${logfile}" 2>&1

# Keep the base environment up to date.
eval "${clone_dir}/tools/update_base.sh" "${base_dir}" >> "${logfile}"

# Build things from the temp directory

pushd "${clone_dir}" >/dev/null 2>&1
mkdir -p "build"
pushd "build" >/dev/null 2>&1

# Config to use.  Change to "universe" once that config exists.
config="default"

eval "${clone_dir}/soconda.sh" \
    -b "${base_dir}" \
    -c "universe" \
    -e "${env_name}" \
    -v "${env_version}" \
    -m "${module_dir}" >> "${logfile}" 2>&1

popd >/dev/null 2>&1
popd >/dev/null 2>&1

# Update permissions
chmod -R g-w,g+rX "${env_name}_${env_version}" >> "${logfile}" 2>&1
chmod -R g-w,g+rX "${module_dir}/soconda" >> "${logfile}" 2>&1

# Return name of log file
echo "${logfile}"
