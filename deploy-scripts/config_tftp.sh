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
    # config uefi
    if [ "${tree_name}" = 'linaro' ];then
        cp -f /tftp/linaro_install/CentOS/linaro_centos.grub.cfg /tftp/linaro_install/grub.cfg
    elif [ "${tree_name}" = 'open-estuary' ];then
        cp -f /tftp/estuary_install/grub.cfg /tftp/grub.cfg
    fi

    cp -f /tftp/estuary_install/estuary.txt.${distro_name,,} /tftp/estuary_install/estuary.txt
}

config_tftp "$@"
