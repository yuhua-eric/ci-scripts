#!/bin/bash -ex

__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
source "${script_path}/../common.sh"

cd "${script_path}"

# read config from config file
cd ../
DHCP_SERVER=${DHCP_SERVER:-`python configs/parameter_parser.py -f config.yaml -s DHCP -k ip`}
cd -

# config file
DHCP_CONFIG_DIR=/etc/dhcp
DHCP_FILENAME=dhcpd.conf

./scripts/gen_dhcpd_conf.sh > dhcpd.conf;

sshpass -p 'root' scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ../dhcpd.conf root@${DHCP_SERVER}:/etc/dhcp/dhcpd.conf
sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${DHCP_SERVER} service isc-dhcp-server restart
