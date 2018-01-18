#!/bin/bash -ex
__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
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

function init_os_dict() {
    # declare global dict
    declare -A -g os_dict
    os_dict=( ["centos"]="CentOS" ["ubuntu"]="Ubuntu")
}

function bmc_vmm_connect() {
    local SSH_PASS="Huawei12#$"
    local SSH_USER="root"
    local SSH_IP=${BMC_IP}

    init_os_dict
    sshpass -p ${SSH_PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${SSH_IP} \
            ipmcset -t vmm -d connect -v nfs://${NFS_BMC_IP}/var/lib/lava/dispatcher/tmp/iso_install/arm64/estuary/${version_name}/"${distro_name}"/"${DEVICE_TYPE,,}"/auto-install.iso
}

# TODO : trap signal to disconnect bmc
function bmc_vmm_disconnect() {
    local SSH_PASS="Huawei12#$"
    local SSH_USER=root
    local SSH_IP=${BMC_IP}

    sshpass -p ${SSH_PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${SSH_IP} ipmcset -t vmm -d disconnect
}

function do_deploy() {
    if [ "${BOOT_PLAN}" = "BOOT_PXE" ];then
        :
    elif [ "${BOOT_PLAN}" = "BOOT_ISO" ];then
        :
        # mount iso
        bmc_vmm_disconnect || true
        bmc_vmm_connect
    fi

    # do deploy
    sleep 10
    python deploy.py --host ${BMC_IP} --type ${BOOT_PLAN}

    # wait the sshd service restart
    sleep 10
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

    sshpass -p ${SSH_PASS} ssh-copy-id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${SSH_IP}

    sleep 5
}

do_deploy "$@"
