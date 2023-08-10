# Simons Observatory Conda Tools

This repository contains scripts to help with:

- Installing a conda base system (optional)

- Creating a conda environment with a well-defined set of conda and pip packages

- Building a few legacy compiled packages into this environment

- Creating a versioned modulefile for loading the environment

## Using an Existing Environment

If you are just using an already-created environment, you can follow
instructions on project resources (Confluence) for how to load a particular
version on a system. After loading an environment, there are a several ways to
customize things.

### Overriding a Few Packages

Each `soconda` modulefile sets the user directory (for `pip install --user`) to
be in a versioned location in your home directory. If you want to use a
different / newer version of `sotodlib` (for example), then you can just do:

    $> pip install --user https://github.com/simonsobs/sotodlib/archive/master.tar.gz

If you swap to a different `soconda` environment, your user package install
directory will also switch.

### More Extensive Customization

One benefit of an `soconda` environment is that it also contains conda packages
built for some legacy compiled tools. If you want to keep those, but
dramatically change which other conda packages are installed, you can first
create a new personal environment while cloning an existing one:

    $> conda create --clone soconda_20230809_1.0.0 /path/to/my/env

Then activate your new environment and conda install whatever you like:

    $> conda activate /path/to/my/env
    $> conda install foo bar blat

Note that your pip user directory will still be set to the location created by
the original upstream module, and you can also "`pip install --user`"
additional packages to go with your custom conda environment.

### Rolling Your Own

You can also just load a conda base environment on a particular system and then
read the rest of this document to install your own environment. You can edit
the files:

    packages_conda.txt
    packages_local.txt
    packages_pip.txt

to control which packages will be installed with conda, pip, or built locally.

## Creating a Simons Observatory Environment

The install script takes options to specify the location of the base environment
(if it is not already activated) and the name (or full path) of the environment
to create. It also allows specifying a central location to install the
modulefile.

---
**NOTE**

Running the `soconda.sh` script will create log files and downloaded sources in
the current directory. Consider running the command from within a temporary
build directory to avoid clutter.

---

### Base Conda Environment

If you already have a conda-forge base environment, then you can skip this
step. Otherwise, decide on the install prefix for your overall conda
environment. For this example, we will use `/opt/conda` as the path to the
conda base installation. Now run the bootstrap script:

    $> ./tools/bootstrap_base "/opt/conda"

This bootstrap will install a base system with the conda-forge channel set to
the default. You can now source the conda initialization file and activate the
base environment:

    $> source /opt/conda/etc/profile.d/conda.sh
    $> conda activate base

After installing an `soconda` environment below, the resulting module file will
do this on load.

### Special Note on mpi4py

By default, the conda package for mpi4py will be installed using the mpich
flavor. This should work well for stand-alone workstations or single nodes. If
you have a cluster with a customized MPI compiler, then set the `MPICC`
environment variable to the MPI C compiler before creating an environment. That
will cause the mpi4py package to be built using your compiler.

### Example:  Local System

Starting from scratch, bootstrap a small conda-forge base environment in `~/conda`:

    $> ./tools/bootstrap_base.sh ~/conda
    $> source ~/conda/etc/profile.d/conda.sh
    $> conda activate base

Create an `soconda` environment with default name and version. However, we
decide to put all the modulefiles into a central location in the root of the
base conda install:

    $> ./soconda.sh -b ~/conda -m ~/conda/modulefiles

Now we can load the module:

    $> module use ~/conda/modulefiles
    $> module avail
    $> module load soconda/XXXXXX

### Example:  NERSC

At NERSC, the default provided python is from Anaconda, and cannot be easily
customized for our needs. Instead, we have a conda-forge base system installed
in our project software directory:

    $> source /global/common/software/sobs/perlmutter/conda/etc/profile.d/conda.sh
    $> conda activate base

Now we can either install a shared software environment or use this base environment to build a conda environment in a personal directory.

## Loading an Environment

The created conda environment includes the root "name" (or path) specified at
creation time and has the version appended to this. For example, if you did not
specify the name or the version, then it would have created an environment under
`envs/soconda_<git version>`.

### Loading an Environment with a Modulefile

There is a module file installed with each soconda environment. If you
specified the module directory during install, then a module named after the
version was created in that directory. The module file will initialize the
conda base environment and then activate the environment you created.

Ensure that the location of the modulefile is in your search path:

    # (If you specified a custom module file directory)
    $> module use /path/to/custom/modulefiles

    # OR (you are using the defaults, and your base install is in /opt/conda)
    $> module use /opt/conda/envs/soconda_1.0.0/modulefiles

And then load the module:

    $> module load soconda/1.0.0

Doing a `module unload soconda` will deactivate the conda environment and
remove any conda initialization from your shell environment.

### Running Tests

After loading an `soconda` environment, you can run some tests with:

    $> ./run_tests.sh

## Customizing an Environment

If you want to dramatically change the package versions / content of an
`soconda` stack, just load the existing base conda environment and edit the
three lists of packages (`packages_[conda|pip|local].txt`) to exclude certain
packages or add extras. Then install it to some personal location outside the
base install (i.e. pass the full path to `soconda -e <path>`).

## Deleting an Environment

The `soconda` environments are self contained and you can delete them by
removing the path or (if using a name), removing the
`<base dir>/envs/<name of env>` directory. You can optionally delete the
modulefile and the pip local directory in your home directory.

## Advanced Details

The compiled packages assume the use of the conda compilers for consistency with
the libraries installed through conda. If you want to change those compilers you
can remove the `compilers` conda package and manually set the `CC`, `CXX`, and `FC`
environment variables. Full warning that this may cause problems with threading
interfaces, thread pinning, etc, when building packages that use OpenMP.

### Pixell

We currently build pixell from source with the conda compilers for consistency,
rather than installing the wheel.

### So3g

This package is currently built from source by default, but the pre-built wheel
(which comes bundled with OpenMP-enabled libopenblas) should also work. To use
that, comment out the so3g line in `packages_local.txt` and uncomment the
line in `packages_pip.txt`.

### TOAST

This package is currently built from source by default, with dependencies
installed through conda. When toast-3.0 arrives in the conda-forge toast
feedstock, it should be added back to `packages_conda.txt`. It should also work
to install the python wheel package by commenting out the toast entry in
`packages_local.txt` and adding it to `packages_pip.txt`.


