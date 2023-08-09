#SCRON --qos=workflow
#SCRON --account=mp107
#SCRON --time=03:00:00
#SCRON --dependency=singleton
#SCRON --name=soconda_latest_tag
0 * * * * /global/u2/s/sobs/software/git/soconda/deploy/install_nersc_tag.sh
