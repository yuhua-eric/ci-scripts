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
PLATFORM=${3:-"D05"}
hpm_dir=/fileserver/open-estuary/$version_name/binary/$PLATFORM
des_dir=/root/update_uefi/${version_name}/$PLATFORM
cd ../
BMC_IP=$(python configs/parameter_parser.py -f devices.yaml -s ${HOST_NAME} -k bmc)
DEVICE_TYPE=$(python configs/parameter_parser.py -f devices.yaml -s ${HOST_NAME} -k type)
#version_name=$(python configs/parameter_parser.py -f config.yaml -s Ftpinfo -k ip)
cd -
function scp_hpm() {
    local SSH_PASS="Huawei12#$"
    local SSH_USER=root
    local SSH_IP=${BMC_IP}
    pushd hpm_dir
    file_name=`ls *.hpm`
    popd
     [ -d ${des_dir} ] && rm -fr ${des_dir}
    mkdir -p ${des_dir}
    cp ${hpm_dir}/${file_name} ${des_dir}
    sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null  "${des_dir}/${file_name}" root@${SSH_IP}:"/tmp"
}

function update_uefi() {

    local SSH_PASS="Huawei12#$"
    local SSH_USER="root"
    local SSH_IP=${BMC_IP}
    timeout 360 sshpass -p ${SSH_PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${SSH_IP} \
            ipmcset -d upgrade -v /tmp/UEFI_D05.hpm
}
function ipmi_power_reset() {
    local IPMI_PASS="Huawei12#$"
    local IPMI_USER=root
    local IPMI_IP=${BMC_IP}

    ipmitool -H ${IPMI_IP} -I lanplus -U ${IPMI_USER} -P ${IPMI_PASS} power reset
}


function config_uefi() {
    # config tver
    local tree_name=${1:-"open-estuary"}
    local host_name=${2:-"d05ssh01"}
    local PLATFORM=${3:-"D05"}
    local version_name=${4:-"v5.1"}
    
    #scp_hpm
    #update_uefi | grep 'successfully'


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
        #elif [ "${version_name}" = "v5.1" ];then
	else
            # do deploy
            if [ "${DEVICE_TYPE}" = "D03" ];then
                python update_uefi_1.py --uefi $file_name --host ${BMC_IP} --ver ${version_name} --plat $DEVICE_TYPE
            elif [ "${DEVICE_TYPE}" = "D05" ];then
                scp_hpm
                update_uefi | sed -n '/successfully/p' > ./update_tmp.txt
	        if [ -s ./update_tmp.txt ]; then
                echo "update ${HOST_NAME}uefi ok" >> update_result.txt
                else
                echo "update ${HOST_NAME}uefi fail" >> update_result.txt
		ipmi_power_reset
		cat update_result.txt
                fi
            fi
        fi
    fi
}

config_uefi "$@"
