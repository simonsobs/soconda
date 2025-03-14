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

## Changing the Build Configuration

The `config/common.txt` file contains conda packages that should be installed on all systems.  There are subdirectories under `config` for each unique machine / build configuration.  Here we discuss the contents of each of these subdirectories.

### Environment Setup

There are two optional files which can be used to control how the environment is set up.
After installation, an optional soconda modulefile is installed. You can add custom
initialization lines to this module file by placing them in a file named:

    config/<name_of_config>/module_init

The lines in this file should be compatible with whatever module flavor is used on the
system. For example, if the system is using lmod, then this snippet should be lua
commands. If the system is using TCL based modules, then this snippet should be tcl
commands.

When building / installing soconda, you can place arbitrary shell commands in a file
named:

    config/<name_of_config>/build_env.sh

This file will be sourced by the `soconda.sh` script before starting. Note that these
commands are only executed during the installation. For run time setup, put module
commands in the `module_init` file.

### Package Selection

There are 3 files that control which packages are installed for a particular
configuration (in addition to the conda-forge packages listed in `config/common.txt`).
To specify packages (including the python version) to be installed from conda-forge, add
those to:

    config/<name_of_config>/packages_conda.txt

To control which conda packages should be built from the local recipes, add packages to:

    config/<name_of_config>/packages_local.txt

And finally, to install packages with pip, add them to the file:

    config/<name_of_config>/packages_pip.txt

Note that each of these pip packages is analyzed with `pipgrip` to find their
dependencies and those dependencies are installed with conda if available. This reduces
the number PyPI packages that end up in the final environment.

### Post-install Steps

An optional shell snippet can be specified at:

    config/<name_of_config>/post_install.sh

And this file will be sourced in soconda.sh after the installation is complete, and
while the installed environment is active. This file can contain arbitrary shell
commands to do things like change permissions, override a package, etc. There are also 2
shell variables that can be modified in this file which control behavior at the end of
soconda.sh:

    install_module=yes
    install_jupyter_setup=yes

The first option controls whether to install the soconda modulefile. Enabling the second
option will install a script that allows users to create a jupyter kernel file for the
soconda stack.

## Updating Bundled Recipes

The conda recipes for bundled packages should be updated whenever upstream
packages have new releases. This involves the following steps:

1.  Update the version in the `meta.yaml` file of the package recipe.

2.  Update the download URL if needed.

3.  Compute the new sha256:

    curl -sL https://github.com/username/reponame/archive/vX.X.X.tar.gz | openssl sha256

4.  Copy the hash into the `meta.yaml` file.

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
