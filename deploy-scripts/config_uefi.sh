#!/bin/bash
__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
cd "${script_path}"

function config_uefi() {
    # config tftp
    local tree_name="$1"
    if [ "${tree_name}" = 'linaro' ];then
        # do deploy
        python update_uefi.py --uefi UEFI_D05_linaro_16_12.fd
    elif [ "${tree_name}" = 'open-estuary' ];then
        # do deploy
        python update_uefi.py --uefi UEFI_D05_Estuary.fd
    fi
}

config_uefi "$@"
