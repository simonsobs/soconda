# Creating a Simons Observatory Environment

The install script takes options to specify the location of the base environment
(if it is not already activated) and the name (or full path) of the environment
to create. It also allows specifying a central location to install the
modulefile:

    $> ./soconda.sh -h
        Usage:  ./soconda.sh
        [-c <directory in config to use for options>]
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

If you already have a conda-forge or micromamba base environment, then you can skip this
step. However, you should consider setting the "solver" in the base environment
to use `libmamba`. To use `libmamba` solver see
[this](https://www.anaconda.com/blog/a-faster-conda-for-a-growing-community) article.
This will greatly speed up the dependency resolution
calculation.

For new installation run following script to install miniforge
```
./tools/bootstrap_base "$HOME/miniforge3"
```
This will intall conda to `$HOME/miniforge3` directory.
It will set conda-forge as default channel and use `libmamba` as default solver.
After the installation you need to re-login or start a new terminal to initialize conda.

After installing an `soconda` environment below, you will not need this step
since it is done by the generated modulefile.

## Special Note on mpi4py

By default, the conda package for mpi4py will be installed. This should work
well for stand-alone workstations or single nodes. If you have a cluster with a
customized MPI compiler, then set the `MPICC` environment variable to the MPI C
compiler before running `soconda.sh`. That will cause the mpi4py package to
be built using your system MPI compiler.

## Example:  Local System
This installation could install `soconda` to your local computer and any cluster.

Clone soconda repo
```
git clone git@github.com:simonsobs/soconda.git
cd soconda
```

Run the `soconda.sh` script
```
export MAKEFLAGS='-j 4'
bash soconda.sh -e soconda -c default
```
This will create a new environment `soconda_xxx.x.x` with version number as suffix
using `default` configuration. [More details on configuration.](#customizing-an-environment)
(The `MAKEFLAGS` doesn't seem to have any effect.)
If you want to specify a conda base directory add `-b "$HOME/miniforge3"` argument to `soconda.sh`.

You could find out the name of new created environment with
```
conda env list
```

Then you can now activate the environment with
```
conda activate soconda_xxx.x.x
```

If running on a Linux desktop that uses wayland, you also need to install the `qt-wayland` package
```
conda install qt-wayland
```

If running on server, start jupyterlab listening on port `12345` with command
```
cd /path/to/project
nohup jupyter-lab --no-browser --port=12345 &> jupyter.log &
```

To list current running jupyter server:
```
jupyter server list
```

To connect to jupyterlab running on server, start SSH tunnel from your laptop/desktop:
```
ssh -N -L 12345:localhost:12345 server_domain_or_ip
```
Then you can connect to jupyterlab with link provided by command `jupyter server list`.

To stop jupyterlab listenging on port 12345:
```
jupyter server stop 12345
```

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

    $> mkdir -p ~/conda_envs
    $> ./soconda.sh -e ~/conda_envs/soconda -m ~/conda_envs/modulefiles

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

When running `soconda.sh`, the system configuration to use can be specified
with the `-c` option. This should be the name of the configuration subdirectory
with the "config" top-level directory. If not specified, the "default" config
is used. If you want to dramatically change the package versions / content of
an `soconda` stack, just load the existing `base` conda environment, copy one
of the configs to a new name and edit the three lists of packages
(`packages_[conda|pip|local].txt`) to exclude certain packages or add extras.
Then install it as usual.

## Deleting an Environment

The `soconda` environments are self contained and you can delete them by
running command `conda remove --name envname --all` or `conda remove -p /base_dir/envs/name --all`.
Or directly removing the `<base dir>/envs/<name of env>` directory.
You can optionally delete the modulefile and the versioned pip
local directory in your home directory.

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


