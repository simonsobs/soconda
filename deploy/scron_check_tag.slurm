# OPTION 1
#
#SCRON --qos=workflow
#SCRON --account=mp107b
#SCRON --time=03:00:00
#SCRON --dependency=singleton
#SCRON --name=soconda_latest_tag
#44 * * * * /global/homes/s/sobs/software/git/soconda/deploy/install_nersc_tag.sh
#
# OPTION 2
#
#SCRON -q cron
#SCRON -A mp107b
#SCRON -t 03:00:00
#44 */3 * * * /global/homes/s/sobs/software/git/soconda/deploy/install_nersc_tag.sh
