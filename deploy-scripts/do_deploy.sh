#!/bin/bash -ex
#: Title                  : do_deploy.sh
#: Usage                  : ./do_deploy.sh ${tree_name} ${host_name} ${distro_name} ${version_name} ${BOOT_PLAN}
#: Author                 : qinsl0106@thundersoft.com
#: Description            : 做自动部署

__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
source "${script_path}/common.sh"
cd "${script_path}"

TREE_NAME=${1:-"open-estuary"}
HOST_NAME=${2:-"d05ssh01"}
distro_name=${3:-"centos"}
version_name=${4:-"v3.1"}

# add for ISO install way
BOOT_PLAN=${5:-"BOOT_PXE"}

cd ../
BMC_IP=$(python configs/parameter_parser.py -f devices.yaml -s ${HOST_NAME} -k bmc)
TARGET_IP=$(python configs/parameter_parser.py -f devices.yaml -s ${HOST_NAME} -k ip)
NFS_BMC_IP=$(python configs/parameter_parser.py -f config.yaml -s NFS -k BMC_IP)
DEVICE_TYPE=$(python configs/parameter_parser.py -f devices.yaml -s ${HOST_NAME} -k type)
cd -

# TODO : check the sshpass result
function bmc_vmm_connect() {
    local SSH_PASS="Huawei12#$"
    local SSH_USER="root"
    local SSH_IP=${BMC_IP}

    init_os_dict
    timeout 120 sshpass -p ${SSH_PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${SSH_IP} \
            ipmcset -t vmm -d connect -v nfs://${NFS_BMC_IP}/var/lib/lava/dispatcher/tmp/iso_install/arm64/estuary/${version_name}/"${distro_name}"/"${DEVICE_TYPE,,}"/auto-install.iso
}

# TODO : trap signal to disconnect bmc
function bmc_vmm_disconnect() {
    local SSH_PASS="Huawei12#$"
    local SSH_USER=root
    local SSH_IP=${BMC_IP}

    timeout 120 sshpass -p ${SSH_PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${SSH_IP} ipmcset -t vmm -d disconnect
}

# ensure poweroff the device
function ipmi_power_off() {
    local IPMI_PASS="Huawei12#$"
    local IPMI_USER=root
    local IPMI_IP=${BMC_IP}

    ipmitool -H ${IPMI_IP} -I lanplus -U ${IPMI_USER} -P ${IPMI_PASS} power off
}

function do_deploy() {
    # close the device first. so that if install fail , it will not mount the old system
    ipmi_power_off
    if [ "${BOOT_PLAN}" = "BOOT_PXE" ];then
        :
    elif [ "${BOOT_PLAN}" = "BOOT_ISO" ];then
        :
        # mount iso
        bmc_vmm_disconnect || true
        # successfully is the vmm connect successs output
        bmc_vmm_connect | grep 'successfully'
    fi

    # do deploy
    sleep 10
    python deploy.py --host ${BMC_IP} --type ${BOOT_PLAN}

    # wait the sshd service restart
    sleep 20
    copy_ssh_id

    if [ "${BOOT_PLAN}" = "BOOT_PXE" ];then
        :
    elif [ "${BOOT_PLAN}" = "BOOT_ISO" ];then
        :
        # umount iso
        bmc_vmm_disconnect
    fi
}

function copy_ssh_id(){
    local SSH_PASS=root
    local SSH_USER=root
    local SSH_IP=${TARGET_IP}

    timeout 60 sshpass -p ${SSH_PASS} ssh-copy-id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${SSH_IP}

    sleep 5
}

do_deploy "$@"
