#!/bin/bash -ex
#: Title                  : config_dhcp.sh
#: Usage                  : ./config_dhcp.sh ${tree_name} ${host_name} ${distro_name} ${version_name} ${BOOT_PLAN}
#: Author                 : qinsl0106@thundersoft.com
#: Description            : 配置dhcp


__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
source "${script_path}/common.sh"

cd "${script_path}"

# read config from config file
cd ../
DHCP_SERVER=${DHCP_SERVER:-`python configs/parameter_parser.py -f config.yaml -s DHCP -k ip`}
cd -

# config file
DHCP_CONFIG_DIR=/etc/dhcp
DHCP_FILENAME=dhcpd.conf

tree_name=${1:-"open-estuary"}
host_name=${2:-"d05ssh01"}
distro_name=${3:-"centos"}
version_name=${4:-"v5.0"}
# add for ISO install way
BOOT_PLAN=${5:-"BOOT_PXE"}


function config_dhcp() {
    # TODO : think generate diffrent dhcp config by tree name
    cd ..;
    # TODO : it may cause fail when update the devices info
    workaround_pop_devices_config
    if [ "${tree_name}" = 'linaro' ];then
        # config dhcp
        # change filename
        python configs/parameter_parser.py -f devices.yaml -s ${host_name} -k filename -w "pxe_install/arm64/linaro/${version_name}/${distro_name}/${host_name%%ssh*}/grubaa64.efi"
        ./scripts/gen_dhcpd_conf.sh > dhcpd.conf;
    elif [ "${tree_name}" = 'open-estuary' ];then
        python configs/parameter_parser.py -f devices.yaml -s ${host_name} -k filename -w "pxe_install/arm64/estuary/${version_name}/${distro_name}/${host_name%%ssh*}/grubaa64.efi"
        ./scripts/gen_dhcpd_conf.sh > dhcpd.conf;
    fi
    workaround_stash_devices_config
    cd -

    sshpass -p 'root' scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ../dhcpd.conf root@${DHCP_SERVER}:/etc/dhcp/dhcpd.conf
    sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${DHCP_SERVER} service isc-dhcp-server restart
}

if [ "${BOOT_PLAN}" = "BOOT_PXE" ];then
    config_dhcp "$@"
elif [ "${BOOT_PLAN}" = "BOOT_ISO" ];then
    :
fi
