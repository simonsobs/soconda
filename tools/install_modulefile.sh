# Modulefile install snippet.  This is sourced from the main
# `soconda.sh` script and uses variables defined there.

# The env root name, used for the name of the generated module file
envroot=$(basename ${envname})

# The optional module init for this config
modinit="${confdir}/module_init"

if [ -z "${moduledir}" ]; then
    # No centralized directory was specified for modulefiles.  Make
    # a subdirectory within the environment itself.
    moduledir="${CONDA_PREFIX}/modulefiles"
fi
mkdir -p "${moduledir}/${envroot}"
if [ -z "${LMOD_VERSION}" ]; then
    # Using TCL modules
    input_mod="${scriptdir}/templates/modulefile_tcl.in"
    outmod="${moduledir}/${envroot}/${version}"
else
    # Using LMOD
    input_mod="${scriptdir}/templates/modulefile_lua.in"
    outmod="${moduledir}/${envroot}/${version}.lua"
fi
rm -f "${outmod}"

while IFS='' read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ @MODLOAD@ ]]; then
        if [ -e "${modinit}" ]; then
            cat "${modinit}" >> "${outmod}"
        fi
    else
        echo "${line}" | eval sed ${confsub} >> "${outmod}"
    fi
done < "${input_mod}"
