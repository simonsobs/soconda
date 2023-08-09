#SCRON --qos=workflow
#SCRON --account=mp107
#SCRON --time=03:00:00
#SCRON --dependency=singleton
#SCRON --name=soconda_latest_tag
0 * * * * /global/homes/s/sobs/git/soconda/deploy/install_nersc_tag.sh
