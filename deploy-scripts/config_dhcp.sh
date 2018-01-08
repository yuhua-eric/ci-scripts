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

function workaround_stash_devices_config() {
    if [ -n "${CI_ENV}" ];then
        :
    else
        CI_ENV=dev
    fi
    if [ -e "configs/"${CI_ENV}"/devices.yaml" ];then
        cp -f configs/"${CI_ENV}"/devices.yaml /tmp/devices.yaml
    fi
}

function workaround_pop_devices_config() {
    if [ -n "${CI_ENV}" ];then
        :
    else
        CI_ENV=dev
    fi

    if [ -e "/tmp/devices.yaml" ];then
        cp -f /tmp/devices.yaml configs/"${CI_ENV}"/devices.yaml
    fi
}

function config_dhcp() {
    local tree_name=${1:-"open-estuary"}
    local host_name=${2:-"d05ssh01"}
    local distro_name=${3:-"centos"}
    local version_name=${4:-"v3.1"}

    # TODO : think generate diffrent dhcp config by tree name
    cd ..;
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

config_dhcp "$@"
