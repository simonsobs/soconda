# Simons Observatory Conda Tools

This repository contains scripts to help with:

- Installing a conda base system (optional)

- Creating a conda environment with a well-defined set of conda and pip packages

- Building a few legacy compiled packages into this environment

- Creating a versioned modulefile for loading the environment

## Base Conda Environment

If you already have a conda base environment, then you can skip this step.  Otherwise,
decide on the install prefix for your overall conda environment.  For this example, 
we will use `/opt/conda` as the path to the conda base installation.  Now run the
bootstrap script:

    $> ./bootstrap_base "/opt/conda"

This bootstrap will install a base system with the conda-forge channel set to the
default.  You can now source the conda initialization file and activate the base
environment:

    $> source /opt/conda/etc/profile.d/conda.sh
    $> conda activate base

After installing an `soconda` environment below, the resulting module file will do this
on load.

## Creating a Simons Observatory Environment

The install script takes options to specify the location of the base environment (if it
is not already activated) and the name (or full path) of the environment to create.  It
also allows specifying a central location to install the modulefile.



### Example:  Local System


### Example:  NERSC


### Example:  Simons1



## Loading an Environment

Ensure that the location of the modulefile is in your search path:

    $>  module use /path/to/modulefiles

And then load the desired version:

    $>  module load soconda/default



## Customizing an Environment

When you load an `soconda` module, it sets the user local pip install directory to 
a versioned location within your home directory.  You can then pip-install packages with
the `--user` option to override packages in the conda environment.

If you want to dramatically change the package versions / content of an `soconda` stack,
it is likely easier to just use the existing base environment and run...


## Deleting an Environment

The `soconda` environments are self contained and you can delete them by removing the
path or (if using a name), removing the `<base dir>/envs/<name of env>` directory.  You
can optionally delete the modulefile and the pip local directory in your home directory.



