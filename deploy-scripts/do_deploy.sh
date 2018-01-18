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
BOOT_PLAN=${5:-"BOOT_NFS"}

cd ../
BMC_IP=$(python configs/parameter_parser.py -f devices.yaml -s ${HOST_NAME} -k bmc)
TARGET_IP=$(python configs/parameter_parser.py -f devices.yaml -s ${HOST_NAME} -k ip)
cd -

function do_deploy() {
    if [ "${BOOT_PLAN}" = "BOOT_PXE" ];then
        :
    elif [ "${BOOT_PLAN}" = "BOOT_ISO" ];then
        :
        # mount iso
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
    fi
}

function copy_ssh_id(){
    SSH_PASS=root
    SSH_USER=root
    SSH_IP=${TARGET_IP}

    sshpass -p ${SSH_PASS} ssh-copy-id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${SSH_IP}

    sleep 5
}

do_deploy "$@"
