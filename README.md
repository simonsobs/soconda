# Simons Observatory Conda Tools

This repository contains scripts to help with:

- Installing a conda base system (optional)

- Creating a conda environment with a well-defined set of conda and pip packages

- Building a few legacy compiled packages into this environment

- Creating a versioned modulefile for loading the environment

## Base Conda Environment

If you already have a conda base environment, then you can skip this step.
Otherwise, decide on the install prefix for your overall conda environment. For
this example, we will use `/opt/conda` as the path to the conda base
installation. Now run the bootstrap script:

    $> ./bootstrap_base "/opt/conda"

This bootstrap will install a base system with the conda-forge channel set to
the default. You can now source the conda initialization file and activate the
base environment:

    $> source /opt/conda/etc/profile.d/conda.sh
    $> conda activate base

After installing an `soconda` environment below, the resulting module file will
do this on load.

## Creating a Simons Observatory Environment

The install script takes options to specify the location of the base environment
(if it is not already activated) and the name (or full path) of the environment
to create. It also allows specifying a central location to install the
modulefile.



### Example:  Local System


### Example:  NERSC


### Example:  Simons1



## Loading an Environment

The created conda environment includes the root "name" (or path) specified at
creation time and has the version appended to this. For example, if you did not
specify the name or the version, then it would have created an environment under
`envs/soconda-<git version>`.

### Loading an Environment the Conda Way

This is just a normal conda environment, so you can load it by ensuring that you
have sourced the conda init script and then running `conda activate`. For
example, if your conda base install is in `/opt/conda`, and you installed from
the git tag `1.0.0` of soconda, then you would do:

    # NOTE:  if this is the only base conda install
    # you are using, you can safely source that in your
    # shell resource file.
    $> source /opt/conda/etc/profile.d/conda.sh

    # Activate this (or any other) environment
    $> conda activate soconda-1.0.0

### Loading an Environment with a Modulefile

If you prefer working with module files, there is a module file installed with
each soconda environment.  If you specified the module directory during install,
then a module named after the version was created in that directory.  The module
file will initialize the conda base environment and then activate the `soconda`
environment.

Ensure that the location of the modulefile is in your search path:

    # (If you specified a custom module file directory)
    $>  module use /path/to/custom/modulefiles

    # OR (you are using the defaults)
    $>  module use /opt/conda/envs/soconda-1.0.0/modulefiles

And then load the module:

    $>  module load soconda/1.0.0

If using module files, then doing a `module unload soconda` will deactivate the
conda environment and remove any conda initialization from your shell
environment.

## Customizing an Environment

When you load an `soconda` module, it sets the user local pip install directory
to a versioned location within your home directory. You can then pip-install
packages with the `--user` option to override packages in the conda environment.

If you want to dramatically change the package versions / content of an
`soconda` stack, it is likely easier to just use the existing base environment
and run...


## Deleting an Environment

The `soconda` environments are self contained and you can delete them by
removing the path or (if using a name), removing the
`<base dir>/envs/<name of env>` directory. You can optionally delete the
modulefile and the pip local directory in your home directory.



