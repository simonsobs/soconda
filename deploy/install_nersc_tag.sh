#!/bin/bash

#========== Configuration ==================

# Location for persistent soconda checkout
git_dir=${HOME}/software/git/soconda

# Location of installed envs
install_dir=/global/common/software/sobs/perlmutter/conda_envs

# Log dir- make a temp dir in the git checkout
log_dir="${git_dir}/logs"

# Module file directory
module_dir=/global/common/software/sobs/perlmutter/modulefiles

# Typical size of an environment, in GB
typical=6

#===========================================

# Function to check available space in software
get_common_free_gb () {
    cmn_used=$(prjquota --cmn sobs | grep sobs | awk '{print $2}')
    cmn_total=$(prjquota --cmn sobs | grep sobs | awk '{print $3}')
    cmn_remain=$(( ${cmn_total} - ${cmn_used} ))
    echo ${cmn_remain}
}

# Check that NERSC_HOST is set
host=${NERSC_HOST}
if [ "x${host}" = "x" ]; then
    echo "This script only runs at NERSC"
    exit 1
fi

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
echo "Starting at ${now}" > "${log_file}" 2>&1

# Get the module file version that will be installed
mod_ver="${today}_${latest}"

send_log=no
annoy="${git_dir}/.already_annoyed"
remain=$(get_common_free_gb)
if (( remain < typical )); then
    echo "Only ${remain} GB are available in /global/common/software/sobs" >> "${log_file}" 2>&1
    echo "Installing latest tag requires approximately ${typical} GB" >> "${log_file}" 2>&1
    echo "SKIPPING until disk space is cleared." >> "${log_file}" 2>&1
    if [ ! -e "${annoy}" ]; then
        send_log=yes
        touch "${annoy}"
    fi
else
    send_log=yes
    rm -f "${git_dir}/.already_annoyed"
    echo "Latest tag '${latest}' not found, installing..." >> "${log_file}" 2>&1
    echo "Note: ${remain} GB are available in /global/common/software/sobs" >> "${log_file}" 2>&1
    echo "Installing latest tag requires approximately ${typical} GB" >> "${log_file}" 2>&1
    install_log=$(eval "${git_dir}/deploy/install_${host}.sh" "${latest}")
    if [ -f "${install_log}" ]; then
        # There were no errors, and the log file was returned
        cat "${install_log}" >> "${log_file}" 2>&1
    else
        # The script must have printed out some errors
        echo "${install_log}" >> "${log_file}" 2>&1
    fi
fi

# Only update the "stable" symlink if the build completed and the modulefile
# was generated.
mod_dir="${module_dir}/soconda"
mod_latest="${mod_dir}/${mod_ver}.lua"
if [ -e "${mod_latest}" ]; then
    rm -f "${mod_dir}/stable.lua" \
    && ln -s "${mod_latest}" "${mod_dir}/stable.lua"
else
    echo "ERROR:  module file ${mod_latest} was not created- leaving stable symlink" >> "${log_file}" 2>&1
fi

echo "Finished installing tag '${latest}' on host ${NERSC_HOST} at $(date +%Y%m%d-%H%M%S)" >> "${log_file}"

if [ "${send_log}" = "yes" ]; then
    # Get our webhook address from the environment
    slack_web_hook=${SLACKBOT_SOCONDA}

    if [ "x${slack_web_hook}" = "x" ]; then
        echo "Environment variable SLACKBOT_SOCONDA not set- skipping notifications" >> "${log_file}" 2>&1
    else
        # Create the JSON payload.
        slackjson="${log_file}_slack.json"
        headtail=12
        echo -e "{\"text\":\"soconda install tag (log at \`${log_file}\`):\n\`\`\`$(head -n ${headtail} ${log_file} | sed -e "s|'|\\\'|g")\`\`\`\n(Snip)\n\`\`\`$(tail -n ${headtail} ${log_file} | sed -e "s|'|\\\'|g")\`\`\`\"}" > "${slackjson}"
        # Post it.
        slackerror=$(curl -X POST -H 'Content-type: application/json' --data "$(cat ${slackjson})" ${slack_web_hook})
        echo "Slack API post  ${slackerror}" >> "${log_file}" 2>&1
    fi
fi
