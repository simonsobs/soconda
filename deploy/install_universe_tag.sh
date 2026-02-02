#!/bin/bash

#========== Configuration ==================
# Host name
host=universe

while getopts b:t:g:i:m: flag
do
    case "${flag}" in
        b) base_dir=${OPTARG};;
        t) temp_dir=${OPTARG};;
        g) git_dir=${OPTARG};;
        i) install_dir=${OPTARG};;
        m) module_dir=${OPTARG};;
        *) echo "usage: $0 [-b] [-t] [-g] [-i] [-m]" >&2
            exit 1 ;;
    esac
done

# Location for conda base
echo "base_dir = ${base_dir}"

# Location for persistent soconda checkout
echo "git_dir = ${git_dir}"

# Location of installed envs
echo "install_dir = ${install_dir}"

# Module file directory
echo "module_dir = ${module_dir}"

# Log dir- make a temp dir in the git checkout
log_dir="${git_dir}/logs"
echo "log_dir = ${log_dir}"

#===========================================


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
install_script="${git_dir}/deploy/install_${host}.sh"
install_args=" -v ${latest} -b ${base_dir} -t ${temp_dir} -i ${install_dir} -m ${module_dir}"
install_log=$(eval "${install_script} ${install_args}")
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

# Get our webhook address from the environment
slack_web_hook=${SLACKBOT_SOCONDA}

if [ "x${slack_web_hook}" = "x" ]; then
    echo "Environment variable SLACKBOT_SOCONDA not set- skipping notifications" >> "${log_file}"
else
    # Create the JSON payload.
    slackjson="${log_file}_slack.json"
    headtail=12
    echo -e "{\"text\":\"soconda install tag (log at \`${log_file}\`):\n\`\`\`$(head -n ${headtail} ${log_file} | sed -e "s|'|\\\'|g")\`\`\`\n(Snip)\n\`\`\`$(tail -n ${headtail} ${log_file} | sed -e "s|'|\\\'|g")\`\`\`\"}" > "${slackjson}"
    # Post it.
    slackerror=$(curl -X POST -H 'Content-type: application/json' --data "$(cat ${slackjson})" ${slack_web_hook})
    echo "Slack API post  ${slackerror}" >> "${log_file}"
fi
