#!/bin/bash -ex
#: Title                  : config_dhcp.sh
#: Usage                  : ./config_dhcp.sh ${tree_name} ${host_name} ${distro_name} ${version_name} ${BOOT_PLAN}
#: Author                 : qinsl0106@thundersoft.com
#: Description            : 配置dhcp
#: export CI_ENV=test

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

function generate_board_dhcp_config() {
    local device=$1
    device_mac=$(python configs/parameter_parser.py -f devices.yaml -s ${device} -k mac)
    device_ip=$(python configs/parameter_parser.py -f devices.yaml -s ${device} -k ip)
    device_next_server=$(python configs/parameter_parser.py -f devices.yaml -s ${device} -k next-server)

    filename=$(python configs/parameter_parser.py -f devices.yaml -s ${device} -k filename)
    echo "host ${device} {"
    echo "  hardware ethernet ${device_mac};"
    echo "  fixed-address ${device_ip};"
    echo "  next-server ${device_next_server};"
    echo "  filename \"${filename}\";"
    echo "}"
}

function replace_board_dhcp_config() {
    local device=$1
    local nbp_file=$2
    local dhcp_file=$3

    keyword="host ${device} {"
    new_board_dhcp_info=$(generate_board_dhcp_config "${device}")
    if cat dhcpd.conf | grep -q "$keyword";then
        # remove old change
        sed -i '/'"${keyword}"'/,/}/d' dhcpd.conf
    fi
    echo "${new_board_dhcp_info}" >> dhcpd.conf
}

function config_dhcp() {
    # if dhcpd.conf don't exist, use this generate it again.
    # ./scripts/gen_dhcpd_conf.sh > dhcpd.conf;

    cd ..;
    sshpass -p 'root' scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${DHCP_SERVER}:/etc/dhcp/dhcpd.conf dhcpd.conf
    if [ "${tree_name}" = 'linaro' ];then
        # config dhcp
        # change filename
        replace_board_dhcp_config ${host_name} "pxe_install/arm64/linaro/${version_name}/${distro_name}/${host_name%%ssh*}/grubaa64.efi" dhcpd.conf
    elif [ "${tree_name}" = 'open-estuary' ];then
        replace_board_dhcp_config ${host_name} "pxe_install/arm64/estuary/${version_name}/${distro_name}/${host_name%%ssh*}/grubaa64.efi" dhcpd.conf
    fi

    sshpass -p 'root' scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null dhcpd.conf root@${DHCP_SERVER}:/etc/dhcp/dhcpd.conf
    sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${DHCP_SERVER} service isc-dhcp-server restart
    cd -
}

if [ "${BOOT_PLAN}" = "BOOT_PXE" ];then
    config_dhcp "$@"
elif [ "${BOOT_PLAN}" = "BOOT_ISO" ];then
    :
fi
