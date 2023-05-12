#!/bin/bash

url=$1
local=$2
temp="${local}.temp"

if [ ! -e "${local}" ]; then
    echo "Fetching ${local} to current directory..." >&2
    curl --connect-timeout 30 --max-time 300 --retry 5 -SL "${url}" -o "${temp}" &&
        mv "${temp}" "${local}"
else
    echo "Found existing ${local} in current directory." >&2
fi

# Did we get the file?
if [ -e "${local}" ]; then
    echo "${local}"
    exit 0
else
    echo "FAIL"
    exit 1
fi
