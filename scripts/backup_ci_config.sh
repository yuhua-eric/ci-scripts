#!/bin/bash
# use async backup the ci configs in d05compile01

# config d05compile01:
# ssh-keygen
# ssh-copy-id root@192.168.50.122

cd /home/backup
# TODO : hard code 192.168.50.122
rsync -avzh --stats --progress root@192.168.50.122:~/estuary /home/backup/estuary
