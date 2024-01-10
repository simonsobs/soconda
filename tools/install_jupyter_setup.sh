# Jupyter kernel user setup snippet.  This is sourced from the main
# `soconda.sh` script and uses variables defined there.

out_jupyter="${CONDA_PREFIX}/bin/soconda_jupyter.sh"
rm -f "${out_jupyter}"

while IFS='' read -r line || [[ -n "${line}" ]]; do
    echo "${line}" | eval sed ${confsub} >> "${out_jupyter}"
done < "${scriptdir}/templates/jupyter.sh.in"
chmod +x "${out_jupyter}"
