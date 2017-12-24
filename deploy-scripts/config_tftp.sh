#!/bin/bash -ex
__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
cd "${script_path}"

TFTP_DIR=/tftp

TFTP_ESTUARY_GRUB=grub.cfg
TFTP_LINARO_GRUB=linaro_install/grub.cfg


function config_tftp() {
    local tree_name=${1:-"open-estuary"}
    local host_name=${2:-"d05ssh01"}
    local distro_name=${3:-"centos"}
    local version_name=${4:-"v3.1"}

    cd ../
    FTP_SERVER=$(python configs/parameter_parser.py -f config.yaml -s Ftpinfo -k ftpserver)
    TARGET_IP=$(python configs/parameter_parser.py -f devices.yaml -s ${HOST_NAME} -k bmc)
    DEVICE_TYPE=$(python configs/parameter_parser.py -f devices.yaml -s ${HOST_NAME} -k type)
    cd -

    # config uefi
    if [ "${tree_name}" = 'linaro' ];then
        :
    elif [ "${tree_name}" = 'open-estuary' ];then
        if [ "${version_name}" != "v5.0" ];then
            if [[ "${version_name}" =~ "estuary-" ]];then
                if [ -d "/tftp/pxe_install/arm64/estuary/${version_name}" ];then
                    # TODO : think diffrent distro and board
                    cp -r "/tftp/pxe_install/arm64/estuary/v5.0" "/tftp/pxe_install/arm64/estuary/${version_name}"
                    cd "/tftp/pxe_install/arm64/estuary/${version_name}"
                    cd "${distro_name}"
                    cd "${DEVICE_TYPE}"
                    rm -rf netboot
                    wget ${FTP_SERVER}/open-estuary/${version_name}/"${distro_name}"/netboot.tar.gz
                    tar -xzvf netboot.tar.gz
                fi
            fi
        fi
    fi
}

config_tftp "$@"
