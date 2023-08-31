# Creating a Simons Observatory Environment

The install script takes options to specify the location of the base environment
(if it is not already activated) and the name (or full path) of the environment
to create. It also allows specifying a central location to install the
modulefile:

    $> ./soconda.sh -h
        Usage:  ./soconda.sh
        [-e <environment, either name or full path>]
        [-b <conda base install (if not activated)>]
        [-v <version (git version used by default)>]
        [-m <modulefile dir (default is <env>/modulefiles)>]
        [-i <file with modulefile commands to load dependencies> ]

---
**NOTE**

Running the `soconda.sh` script will create log files in the current directory.
Consider running the command from within a temporary build directory to avoid
clutter.

---

## Base Conda Environment

If you already have a conda-forge base environment, then you can skip this
step. However, you should consider setting the "solver" in the base environment
to use libmamba. This will greatly speed up the dependency resolution
calculation. Once you decide on the install prefix for your overall conda
environment you can use the included bootstrap script. For this example, we
will use `/opt/conda` as the path to the conda base installation. Now run the
bootstrap script:

    $> ./tools/bootstrap_base "/opt/conda"

This bootstrap will install a base system with the conda-forge channel set to
the default and using the mamba solver. You can now source the conda
initialization file and activate the base environment:

    $> source /opt/conda/etc/profile.d/conda.sh
    $> conda activate base

After installing an `soconda` environment below, you will not need this step
since it is done by the generated modulefile.

## Special Note on mpi4py

By default, the conda package for mpi4py will be installed. This should work
well for stand-alone workstations or single nodes. If you have a cluster with a
customized MPI compiler, then set the `MPICC` environment variable to the MPI C
compiler before running `soconda.sh`. That will cause the mpi4py package to
be built using your compiler.

## Example:  Local System

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

## Example:  NERSC

At NERSC, the default provided python is from Anaconda, and does not work well
for our needs. Instead, we have a conda-forge base system installed in our
project software directory:

    $> source /global/common/software/sobs/perlmutter/conda/etc/profile.d/conda.sh
    $> conda activate base

Now we can either install a shared software environment or use this base
environment to build a conda environment in a personal directory. If you are
installing to a shared software environment, you should do that as the project
account and follow a specific naming convention which is beyond the scope of
this document. If you wanted to install these tools to your home directory you
could do:

    $> ./soconda.sh -b ~/conda_envs -m ~/conda_envs/modulefiles

And then load the module:

    $> module use ~/conda_envs/modulefiles
    $> module avail
    $> module load soconda/XXXXXX

## Running Tests

After loading an `soconda` environment, you can run some tests with:

    $> ./run_tests.sh

## Installing a Jupyter Kernel

After loading an soconda module the first time, you can run (once) the included script:

    $> soconda_jupyter.sh

This will install a kernel file so that jupyter knows how to launch a kernel
using this python stack.

## Customizing an Environment

If you want to dramatically change the package versions / content of an
`soconda` stack, just load the existing `base` conda environment and edit the
three lists of packages (`packages_[conda|pip|local].txt`) to exclude certain
packages or add extras. Then install it as usual.

## Deleting an Environment

The `soconda` environments are self contained and you can delete them by
removing the path or (if using a name), removing the `<base dir>/envs/<name of
env>` directory. You can optionally delete the modulefile and the pip local
directory in your home directory.

## Advanced Details

The compiled packages assume the use of the conda compilers for consistency with
the libraries installed through conda. If you want to change those compilers you
can remove the `compilers` conda package and manually set the `CC`, `CXX`, and `FC`
environment variables. Full warning that this may cause problems with threading
interfaces, thread pinning, etc, when building packages that use OpenMP.

### Pixell

We currently build pixell from source with the conda compilers for consistency,
rather than installing the wheel.

### Libactpol / Moby2

There are three conda recipes for `libactpol_deps`, `libactpol`, and `moby2`.
These are using git hashes that are either the latest or a branch / version
recommended for S.O. use.

### So3g

This package is currently installed from the wheel, but the conda package is
being tested (using boost from conda-forge).

### TOAST

This package is currently built from source by default, with dependencies
installed through conda. When toast-3.0 arrives in the conda-forge toast
feedstock, it should be added back to `packages_conda.txt`. It should also work
to install the python wheel package by commenting out the toast entry in
`packages_local.txt` and adding it to `packages_pip.txt`.


