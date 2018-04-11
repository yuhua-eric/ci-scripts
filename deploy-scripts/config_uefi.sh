#!/bin/bash
__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
cd "${script_path}"

TREE_NAME=${1:-"open-estuary"}
HOST_NAME=${2:-"d05ssh01"}

cd ../
TARGET_IP=$(python configs/parameter_parser.py -f devices.yaml -s ${HOST_NAME} -k bmc)
DEVICE_TYPE=$(python configs/parameter_parser.py -f devices.yaml -s ${HOST_NAME} -k type)
FTP_IP=$(python configs/parameter_parser.py -f config.yaml -s Ftpinfo -k ip)
cd -

function config_uefi() {
    # config tftp
    local tree_name=${1:-"open-estuary"}
    local host_name=${2:-"d05ssh01"}
    local distro_name=${3:-"centos"}
    local version_name=${4:-"v3.1"}

    if [ "${tree_name}" = 'linaro' ];then
        # do deploy
        if [ "${DEVICE_TYPE}" = "D03" ];then
            python update_uefi.py --uefi UEFI_D03_linaro_16_12.fd --host ${TARGET_IP} --ftp ${FTP_IP}
        elif [ "${DEVICE_TYPE}" = "D05" ];then
            python update_uefi.py --uefi UEFI_D05_linaro_16_12.fd --host ${TARGET_IP} --ftp ${FTP_IP}
        fi

    elif [ "${tree_name}" = 'open-estuary' ];then
        if [ "${version_name}" = "v3.1" ];then
            # do deploy
            if [ "${DEVICE_TYPE}" = "D03" ];then
                python update_uefi.py --uefi UEFI_D03_Estuary.fd --host ${TARGET_IP} --ftp ${FTP_IP}
            elif [ "${DEVICE_TYPE}" = "D05" ];then
                python update_uefi.py --uefi UEFI_D05_Estuary.fd --host ${TARGET_IP} --ftp ${FTP_IP}
            fi
        elif [ "${version_name}" = "v5.0" ];then
            # do deploy
            if [ "${DEVICE_TYPE}" = "D03" ];then
                python update_uefi.py --uefi UEFI_D03_Estuary_V500.fd --host ${TARGET_IP} --ftp ${FTP_IP}
            elif [ "${DEVICE_TYPE}" = "D05" ];then
                python update_uefi.py --uefi UEFI_D05_Estuary_V500.fd --host ${TARGET_IP} --ftp ${FTP_IP}
            fi
        fi
    fi
}

config_uefi "$@"
