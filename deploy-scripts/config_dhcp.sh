#!/bin/bash -ex
__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
cd "${script_path}"

# read config from config file
cd ../
DHCP_SERVER=${DHCP_SERVER:-`python configs/parameter_parser.py -f config.yaml -s DHCP -k ip`}
cd -

# config file
DHCP_CONFIG_DIR=/etc/dhcp
DHCP_FILENAME=dhcpd.conf

function config_dhcp() {
    local tree_name="$1"
    # config dhcp
    if [[ "${CI_ENV}" == "test" ]];then
        scripts/gen_dhcpd_conf.sh > /etc/dhcp/dhcpd.conf
        service isc-dhcp-server restart
    else
        if [ "${tree_name}" = 'linaro' ];then
            sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${DHCP_SERVER} cp -f /etc/dhcp/examples/dhcpd.conf.linaro /etc/dhcp/dhcpd.conf
        elif [ "${tree_name}" = 'open-estuary' ];then
            sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${DHCP_SERVER} cp -f /etc/dhcp/examples/dhcpd.conf.estuary /etc/dhcp/dhcpd.conf
        fi

        sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${DHCP_SERVER} service isc-dhcp-server restart
    fi
}

config_dhcp "$@"
