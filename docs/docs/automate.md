# Automating the Install

The general process of automating the install proceeds like this:

1. A cron job (or similar) runs periodically and launches a script which
examines current tags of soconda and finds the latest one. It looks at the
installation directory and determines whether this tag has been installed. If
not, it runs an installation wrapper script for the current system.

2. The wrapper script has hard-coded paths to the various locations and also
knows how to build the version string to use. This script calls the
`soconda.sh` script to install the latest tag.

3. If a new tag was installed, a message is posted via slack hook to one of the
Simons Observatory slack channels.

## Example:  Perlmutter at NERSC

In the `deploy` subdirectory are the relevant files. The perlmutter install
wrapper script is in `install_perlmutter.sh`. The tag checking script run by
the cron job is in `install_nersc_tag.sh`, and the example lines in the scron
tab are in `scron_check_tag.slurm`.
