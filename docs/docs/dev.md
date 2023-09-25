# Developer Notes

This section covers steps needed when maintaining the `soconda` tools.

## Releases

After updating the versions of included packages, it is a good idea to make a
new release so that a new environment is built and deployed. After all
outstanding changes are merged to `main`, go to the github page for this
repository and click on the `Actions` tab. Trigger the `Test Build` workflow.
This will take an hour or so to run. Assuming it all works, create a new
release with some notes about what was updated. Cron jobs running on our
computing centers will check for new tags and build them if found.

## Changing Installed Packages

The three top-level files: `packages_conda.txt`, `packages_local.txt`, and
`packages_pip.txt` contain the packages that will be installed. The conda
packages are installed first, then local conda packages are built and
installed, and finally the pip packages are installed. When installing pip
packages, the `soconda.sh` script first extracts the dependencies of each pip
package and installs it instead with conda. This helps minimize the number of
pip packages installed in the environment and that makes it easier to avoid
dependency problems later.

## Updating Bundled Recipes

The conda recipes for bundled packages should be updated whenever upstream
packages have new releases. This involves the following steps:

1.  Update the version in the `meta.yaml` file of the package recipe.

2.  Update the download URL if needed.

3.  Manually download the new tarball of the package.  For example:

        curl -SL -o pixel-0.19.0.tar.gz \
        https://github.com/simonsobs/pixell/archive/v0.19.0.tar.gz

4. Get the sha256 checksum of the tarball, and copy that into the `meta.yaml`
entry:

        openssl sha256 pixel-0.19.0.tar.gz
        SHA256(pixell-0.19.0.tar.gz)= 8142a2a368175de845166afffe3e4efd0ac0bdc109a96eb8f4cc0360e6191fd1

5. Ensure that the new version of the package does not have any updated
dependencies or other constraints.

## Adding New Package Recipes

This should not be needed very often, and will require some familiarity with
conda recipes. Create a new directory for the recipe in the `pkgs` directory.
Add a `meta.yaml` file, a `build.sh` file, and a copy of the package license.
See the conda documentation and existing conda-forge feedstocks for extensive
examples. You can load an existing soconda environment as a testbed and then
test your new recipe with `conda build`. After you can build it independently,
add it to the `packages_local.txt` file.
