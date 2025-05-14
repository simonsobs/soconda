#!/bin/bash

#========== Configuration ==================

# Location for persistent soconda checkout
git_dir=/cephfs/soukdata/software/python/soconda

# Location of installed envs
install_dir=/cephfs/soukdata/software/python/soconda_builds

# Log dir- make a temp dir in the git checkout
log_dir="${git_dir}/logs"
echo $log_dir
# Module file directory
module_dir=/cephfs/soukdata/software/modulefiles/

# Host name
host=universe

# If the latest tag is already installed, we do not need to make an
# extra log in the log dir.  We already have a slurm/scron log that is
# always created.

# Update the persistent git checkout and find the most recent tag
pushd "${git_dir}" >/dev/null 2>&1
git checkout main
git fetch --tags
git rebase origin/main
git remote prune origin
latest=$(git describe --tags $(git rev-list --tags --max-count=1))
popd >/dev/null 2>&1

# See if we already have this tag installed
found=no
found_date=""
for item in $(ls ${install_dir}); do
    check=$(echo ${item} | sed -e "s/soconda_.*_\(.*\)/\1/")
    found_date=$(echo ${item} | sed -e "s/soconda_\(.*\)_.*/\1/")
    if [ "${check}" = "${latest}" ]; then
        found=yes
    fi
done

if [ "${found}" = "yes" ]; then
    # Nothing to do
    echo "Latest tag '${latest}' was already installed on ${found_date}"
    exit 0
fi

# If we got this far, we need to install things.

# Make sure log dir exists
mkdir -p "${log_dir}"

now=$(date +%Y%m%d-%H%M%S)
today=$(date +%Y%m%d)
log_file="${log_dir}/check_tags_${host}_${now}"

# Create the log file
echo "Starting at ${now}" > "${log_file}"

# Get the module file version that will be installed
mod_ver="${today}_${latest}"

echo "Latest tag '${latest}' not found, installing..." >> "${log_file}"
install_log=$(eval "${git_dir}/deploy/install_${host}.sh" "${latest}")
if [ -f "${install_log}" ]; then
    # There were no errors, and the log file was returned
    cat "${install_log}" >> "${log_file}"
else
    # The script must have printed out some errors
    echo "${install_log}" >> "${log_file}"
fi

# Only update the "stable" symlink if the build completed and the modulefile
# was generated.
mod_dir="${module_dir}/soconda"
mod_latest="${mod_dir}/${mod_ver}.lua"
if [ -e "${mod_latest}" ]; then
    rm -f "${mod_dir}/stable.lua" \
    && ln -s "${mod_latest}" "${mod_dir}/stable.lua"
else
    echo "ERROR:  module file ${mod_latest} was not created- leaving stable symlink" >> "${log_file}" 
fi

echo "Finished installing tag '${latest}' on host ${host} at $(date +%Y%m%d-%H%M%S)" >> "${log_file}"

