#!/bin/bash -ex
#: Title                  : update_uefi_1.sh
#: Usage                  : ./local/ci-scripts/deploy-scripts/update_uefi_1.sh -p env.properties
#: Author                 : yu_hua1@hoperun.com
#: Description            : CI中自动升级UEFI脚本
__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
cd "${script_path}"

TREE_NAME=${1:-"open-estuary"}
HOST_NAME=${2:-"d05ssh01"}
version_name=${4:-"v5.1"}
HPM_FILE=${3:-"UEFI_D05.hpm"}
cd ../
BMC_IP=$(python configs/parameter_parser.py -f devices.yaml -s ${HOST_NAME} -k bmc)
DEVICE_TYPE=$(python configs/parameter_parser.py -f devices.yaml -s ${HOST_NAME} -k type)
#version_name=$(python configs/parameter_parser.py -f config.yaml -s Ftpinfo -k ip)

cd -
function scp_hpm() {
    local SSH_PASS="Huawei12#$"
    local SSH_USER=root
    local SSH_IP=${BMC_IP}

    sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null  "~/update_uefi/v5.1/D05/UEFI_D05.hpm" root@${SSH_IP}:"/tmp"
}

function update_uefi() {

    local SSH_PASS="Huawei12#$"
    local SSH_USER="root"
    local SSH_IP=${BMC_IP}
    timeout 360 sshpass -p ${SSH_PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${SSH_IP} \
            ipmcset -d upgrade -v /tmp/UEFI_D05.hpm
}


function config_uefi() {
    # config tver
    local tree_name=${1:-"open-estuary"}
    local host_name=${2:-"d05ssh01"}
    local file_name=${3:-"UEFI_D05.hpm"}
    local version_name=${4:-"v5.1"}
    
    scp_hpm
    update_uefi | grep 'successfully'


    if [ "${tree_name}" = 'linaro' ];then
        # do deploy
        if [ "${DEVICE_TYPE}" = "D03" ];then
            python update_uefi_1.py --uefi $file_name --host ${BMC_IP} --ver ${version_name} --plat $DEVICE_TYPE
        elif [ "${DEVICE_TYPE}" = "D05" ];then
            python update_uefi_1.py --uefi $file_name --host ${BMC_IP} --ver ${version_name} --plat $DEVICE_TYPE
        fi

    elif [ "${tree_name}" = 'open-estuary' ];then
        if [ "${version_name}" = "v3.1" ];then
            # do deploy
            if [ "${DEVICE_TYPE}" = "D03" ];then
                python update_uefi_1.py --uefi $file_name --host ${BMC_IP} --ver ${version_name} --plat $DEVICE_TYPE
            elif [ "${DEVICE_TYPE}" = "D05" ];then
                python update_uefi_1.py --uefi $file_name --host ${BMC_IP} --ver ${version_name} --plat $DEVICE_TYPE
            fi
        elif [ "${version_name}" = "v5.1" ];then
            # do deploy
            if [ "${DEVICE_TYPE}" = "D03" ];then
                python update_uefi_1.py --uefi $file_name --host ${BMC_IP} --ver ${version_name} --plat $DEVICE_TYPE
            elif [ "${DEVICE_TYPE}" = "D05" ];then
                scp_hpm
                update_uefi | grep 'successfully'

		 
            fi
        fi
    fi
}

config_uefi "$@"
