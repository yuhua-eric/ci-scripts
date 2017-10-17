#!/bin/bash -ex
DHCP_CONFIG_DIR=/etc/dhcp
DHCP_SERVER=192.168.30.2
DHCP_FILENAME=dhcpd.conf

function config_dhcp() {
    local tree_name="$1"
    # config dhcp
    if [ "${tree_name}" = 'linaro' ];then
        sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.30.2 cp -f /etc/dhcp/examples/dhcpd.conf.linaro /etc/dhcp/dhcpd.conf
    elif [ "${tree_name}" = 'open-estuary' ];then
        sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.30.2 cp -f /etc/dhcp/examples/dhcpd.conf.estuary /etc/dhcp/dhcpd.conf
    fi

    sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.30.2 service isc-dhcp-server restart
}

config_dhcp "$@"
