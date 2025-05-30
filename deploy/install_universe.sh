#!/bin/bash

#========== Configuration ==================

while getopts b:t:i:m:v: flag
do
    case "${flag}" in
        b) base_dir=${OPTARG};;
        t) temp_dir=${OPTARG};;
        i) install_dir=${OPTARG};;
        m) module_dir=${OPTARG};;
        v) version=${OPTARG};;
    esac
done

# Location for conda base
echo "base_dir = ${base_dir}"

# Location for temp clones
echo "temp_dir = ${temp_dir}"

# Location for installs
echo "install_dir = ${install_dir}"

# Module file directory
echo "module_dir = ${module_dir}"

#===========================================

if [ "x${version}" = "x" ]; then
    echo "usage:  $0 <soconda branch/tag/hash>"
    exit 1
else
    echo "Installing soconda version: ${version}"
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
