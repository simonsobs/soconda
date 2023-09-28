# Using an Existing Environment

If you are just using an already-created environment, you can follow
instructions on the Simons Observatory project confluence site (see the Data
Management pages on Computing Infrastructure) about where to find the
installation for a particular system. After loading an environment, there are a
several ways to customize things.

## Overriding a Few Packages

Each `soconda` modulefile sets the user directory (for `pip install --user`) to
be in a versioned location in your home directory. If you want to use a
different / newer version of `sotodlib` (for example), then you can just do:

    $> pip install --user https://github.com/simonsobs/sotodlib/archive/master.tar.gz

If you swap to a different `soconda` environment, your user package install
directory will also switch.

## More Extensive Customization

One benefit of an `soconda` environment is that it also contains conda packages
built for some legacy compiled tools. If you want to keep those, but
dramatically change which other conda packages are installed, you can first
create a new personal environment while cloning an existing one:

    $> conda create --clone soconda_20230809_1.0.0 -p /path/to/my/env

Then activate your new environment and conda install whatever you like:

    $> conda activate /path/to/my/env
    $> conda install foo bar blat

Note that your pip user directory will still be set to the location created by
the original upstream module, and you can also "`pip install --user`"
additional packages to go with your custom conda environment.

## Something Else

You can also just load a conda base environment on a particular system and then
read the next section of this document to install your own environment.
