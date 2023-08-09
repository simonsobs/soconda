#!/bin/bash

#========== Configuration ==================

# Location for persistent soconda checkout
git_dir=${HOME}/software/git/soconda

# Location of installed envs
install_dir=/global/common/software/sobs/perlmutter/conda_envs

# Log dir- make a temp dir in the git checkout
log_dir="${git_dir}/logs"

#===========================================

# Check that NERSC_HOST is set
host=${NERSC_HOST}
if [ "x${host}" = "x" ]; then
    echo "This script only runs at NERSC"
    exit 1
fi

# Make sure log dir exists
mkdir -p "${log_dir}"
now=$(date +%Y%m%d-%H%M%S)
log_file="${log_dir}/check_tags_${host}_${now}"
echo "Starting at ${now}" > "${log_file}" 2>&1

# Update the persistent git checkout and find the most recent tag
pushd "${git_dir}" >/dev/null 2>&1
git checkout main >> "${log_file}" 2>&1
git fetch --tags >> "${log_file}" 2>&1
git rebase origin/main >> "${log_file}" 2>&1
git remote prune origin >> "${log_file}" 2>&1
latest=$(git describe --tags $(git rev-list --tags --max-count=1))
popd >/dev/null 2>&1

# See if we already have this tag installed
found=no
found_date=""
for item in $(ls ${install_dir}); do
    if [ -d ${item} ]; then
	# This is a directory
	check=$(echo ${item} | sed -e "s/soconda_.*_\(.*\)/\1/")
	found_date=$(echo ${item} | sed -e "s/soconda_\(.*\)_.*/\1/")
	if [ "${check}" = "${latest}" ]; then
	    found=yes
	fi
    fi
done

if [ "${found}" = "yes" ]; then
    echo "Latest tag \"${latest}\" was already installed on ${found_date}" >> "${log_file}" 2>&1
else
    echo "Latest tag \"${latest}\" not found, installing..." >> "${log_file}" 2>&1
    # eval "${git_dir}/deploy/install_${host}.sh" "${latest}"
fi

