#!/bin/bash -ex
__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
cd "${script_path}"

TFTP_DIR=/tftp

TFTP_ESTUARY_GRUB=grub.cfg
TFTP_LINARO_GRUB=linaro_install/grub.cfg

tree_name=${1:-"open-estuary"}
host_name=${2:-"d05ssh01"}
distro_name=${3:-"centos"}
version_name=${4:-"v5.0"}

# add for ISO install way
BOOT_PLAN=${5:-"BOOT_PXE"}


cd ../
FTP_SERVER=$(python configs/parameter_parser.py -f config.yaml -s Ftpinfo -k ftpserver)
TARGET_IP=$(python configs/parameter_parser.py -f devices.yaml -s ${HOST_NAME} -k bmc)
DEVICE_TYPE=$(python configs/parameter_parser.py -f devices.yaml -s ${HOST_NAME} -k type)
cd -


function init_os_dict() {
    # declare global dict
    declare -A -g os_dict
    os_dict=( ["centos"]="CentOS" ["ubuntu"]="Ubuntu")
}

function config_tftp_pxe() {
    # config uefi
    if [ "${tree_name}" = 'linaro' ];then
        :
    elif [ "${tree_name}" = 'open-estuary' ];then
        # TODO : for all version , do kernel replace. like if [ "${version_name}" != "v5.0-template" ];then
        if [ "${version_name}" != "v5.0" ];then
            if [[ "${version_name}" =~ "estuary_" ]];then
                if [ ! -d "/tftp/pxe_install/arm64/estuary/${version_name}" ];then
                    cp -r "/tftp/pxe_install/arm64/estuary/v5.0" "/tftp/pxe_install/arm64/estuary/${version_name}"
                fi
                cd "/tftp/pxe_install/arm64/estuary/${version_name}"
                cd "${distro_name}"
                cd "${DEVICE_TYPE,,}"

                # replave netboot
                rm -rf netboot netboot.tar.gz || true
                init_os_dict
                wget ${FTP_SERVER}/open-estuary/${version_name}/"${os_dict[$distro_name]}"/netboot.tar.gz
                tar -xzvf netboot.tar.gz
            fi
        fi
    fi
}


function config_tftp_iso() {
    # config uefi
    if [ "${tree_name}" = 'linaro' ];then
        :
    elif [ "${tree_name}" = 'open-estuary' ];then
        if [ ! -d "/tftp/iso_install/arm64/estuary/${version_name}/${distro_name}/${DEVICE_TYPE,,}" ];then
            mkdir -p "/tftp/iso_install/arm64/estuary/${version_name}/${distro_name}/${DEVICE_TYPE,,}"
            cd "/tftp/iso_install/arm64/estuary/${version_name}/${distro_name}/${DEVICE_TYPE,,}"
            # replave iso
            rm -rf *.iso || true
            init_os_dict
            wget ${FTP_SERVER}/open-estuary/${version_name}/"${os_dict[$distro_name]}"/auto-install.iso
        fi
    fi
}


if [ "${BOOT_PLAN}" = "BOOT_PXE" ];then
    config_tftp_pxe "$@"
elif [ "${BOOT_PLAN}" = "BOOT_ISO" ];then
    config_tftp_iso "$@"
fi
