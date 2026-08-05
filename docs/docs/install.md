# Creating a Simons Observatory Environment

The install script takes options to specify the location of the base environment
(if it is not already activated) and the name (or full path) of the environment
to create. It also allows specifying a central location to install the
modulefile:

    ./soconda.sh -h
        Usage:  ./soconda.sh
        [-c <directory in config to use for options>]
        [-e <environment, either name or full path>]
        [-b <conda base install (if not activated)>]
        [-v <version (git version used by default)>]
        [-m <modulefile dir (default is <env>/modulefiles)>]

---
**NOTE**

Running the `soconda.sh` script will create log files in the current directory.
Consider running the command from within a temporary build directory to avoid
clutter.

---

## Base Conda Environment

If you already have a conda-forge or micromamba base environment, install
`conda-build` and `conda-verify` package to base environment.

    conda update -n base --yes --all conda
    conda install -n base --yes --all conda-build conda-verify

For a new installation of a conda base environment, run the following script to
install miniforge:

    ./tools/bootstrap_base "$HOME/miniforge3"

This will install the base conda environment to the `$HOME/miniforge3`
directory. It will set conda-forge as default channel. After the installation
you need to re-login or start a new terminal to initialize conda. You can
manually activate this base environment, but for the example below this is not
needed.

## Special Note on mpi4py

By default, the conda package for mpi4py will be installed. This should work
well for stand-alone workstations or single nodes. If you have a cluster with a
customized MPI compiler, then set the `MPICC` environment variable to the MPI C
compiler before running `soconda.sh`. That will cause the mpi4py package to
be built using your system MPI compiler.

## Install soconda

### Example:  Local System

This procedure will work to install `soconda` to your local computer or a basic
cluster.  First, clone the soconda repo

    git clone git@github.com:simonsobs/soconda.git
    cd soconda

Run the `soconda.sh` script, specifying the location of the base environment
(`-b`), the name of the configuration to use (`-c`), and the name of the
environment (`-e`):

    ./soconda.sh -b "$HOME/miniforge3" -e soconda -c default

This will create a new environment `soconda_xxx.x.x` with version number as
suffix using `default` configuration. [More details on
configuration.](#customizing-an-environment)

You can find out the name of newly created environment with:

    conda env list

Then you can now activate the environment with:

    conda activate soconda_xxx.x.x

If running on a Linux desktop that uses wayland, you also need to install the
`qt-wayland` package

    conda install qt-wayland

#### Using Jupyter

If you want to use jupyter [first install a kernel for this new soconda environment](#installing-a-jupyter-kernel).
Next just run `jupyter-lab` from a terminal in your directory containing some
notebooks and jupyter-lab should launch in your default browser:

    cd /path/to/project
    jupyter-lab

and then ctrl-c the jupyter-lab terminal job when you are done. If you installed
jupyter-lab on a local "server" and want to connect from your laptop (for
example), you can launch a long-running jupyter session and control what port is
used for communication with the browser on your laptop. For example:

    (on server): nohup jupyter-lab --no-browser --port=12345 &> jupyter.log &

To list the currently running jupyter servers:

    (on server): jupyter server list

To connect to jupyter-lab running on this server, start an SSH tunnel from your
laptop:

    (on laptop): ssh -N -L 12345:localhost:12345 server_domain_or_ip

Then you can connect to jupyterlab with the link provided by command `jupyter
server list`.  To stop jupyterlab listening on port 12345:

    (on server): jupyter server stop 12345

### Example:  NERSC

At NERSC, the default provided python does not work well for our needs. Instead,
we have a conda-forge base environment installed in our project software
directory:

    source /global/common/software/sobs/perlmutter/conda_base/etc/profile.d/conda.sh
    conda activate base

We can either install a shared software environment or use this base environment
to build a conda environment in a personal directory. If you are installing to a
shared software environment, you should do that as the project account and
follow a specific naming convention which is beyond the scope of this document.
If you wanted to install these tools to your home directory you could do:

    mkdir -p ~/conda_envs
    ./soconda.sh -e ~/conda_envs/soconda -m ~/conda_envs/modulefiles

And then load the module:

    module use ~/conda_envs/modulefiles
    module avail
    module load soconda/XXXXXX

## Running Tests

After loading an `soconda` environment, you can run some tests with:

    ./run_tests.sh

## Installing a Jupyter Kernel

After loading an soconda module or activating an soconda conda environment the
first time, you can run (once) the included script:

    soconda_jupyter.sh

This will install a kernel file to
`~/.local/share/jupyter/kernels/soconda-xxxxx` so that the jupyter server knows
how to launch a kernel using this python stack.

## Customizing an Environment

When running `soconda.sh`, the system configuration to use can be specified
with the `-c` option. This should be the name of the configuration subdirectory
within the "config" top-level directory. If not specified, the "default" config
is used. If you want to dramatically change the package versions / content of
an `soconda` stack, just load the existing `base` conda environment, copy one
of the configs to a new name and edit the three lists of packages
(`packages_[conda|pip|local].txt`) to exclude certain packages or add extras.
Then install it as usual.

## Deleting an Environment

The `soconda` environments are self contained and you can delete them by running
command `conda remove --name <envname> --all` or `conda remove -p
/base_dir/envs/name --all`. Or directly removing the `<base dir>/envs/<name of
env>` directory. You can optionally delete the modulefile and the versioned pip
local directory in your home directory. If you installed a jupyter kernel,
remove kernel file in `~/.local/share/jupyter/kernels/` with matching soconda
version.

If you have multiple soconda environments and deleted the wrong kernel file, you
can always [recreate it](#installing-a-jupyter-kernel).

## Advanced Details

The compiled packages assume the use of the conda compilers for consistency with
the libraries installed through conda. If you want to change those compilers you
can remove the `compilers` conda package and manually set the `CC`, `CXX`, and `FC`
environment variables. Full warning that this may cause problems with threading
interfaces, thread pinning, etc, when building packages that use OpenMP.

### Libactpol / Moby2

There are three conda recipes for `libactpol_deps`, `libactpol`, and `moby2`.
These are using git hashes that are either the latest or a branch / version
recommended for S.O. use.

### So3g

This package has a local conda recipe. There is a branch being tested that
remove dependences on boost and compile-time linking to spt3g. Once that is
merged, so3g can migrate upstream to conda-forge.
