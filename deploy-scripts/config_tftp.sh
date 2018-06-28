#!/bin/bash -ex
#: Title                  : config_tftp.sh
#: Usage                  : ./config_tftp.sh ${tree_name} ${host_name} ${distro_name} ${version_name} ${BOOT_PLAN}
#: Author                 : qinsl0106@thundersoft.com
#: Description            : 配置tftp


__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
source "${script_path}/common.sh"

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
NEXT_SERVER=$(python configs/parameter_parser.py -f devices.yaml -s ${HOST_NAME} -k next-server)
cd -


function config_tftp_pxe() {
    # config uefi
    if [ "${tree_name}" = 'linaro' ];then
        :
    elif [ "${tree_name}" = 'open-estuary' ];then
        if [ ! -e "/tftp/pxe_install/arm64/estuary/${version_name}/${distro_name}/${DEVICE_TYPE,,}/" ];then
            mkdir -p "/tftp/pxe_install/arm64/estuary/${version_name}/${distro_name}/${DEVICE_TYPE,,}/"
            cd "/tftp/pxe_install/arm64/estuary/${version_name}/${distro_name}/${DEVICE_TYPE,,}/"
            # replave netboot
            init_os_dict
            # TODO : download config from fileserver and git repo
            # template magic dir. save the grub.cfg fonts NBP files. for pxe install ,we need copy these files
            cd "/tftp/pxe_install/arm64/estuary/template/${distro_name}/${DEVICE_TYPE,,}/" && cp -rf * "/tftp/pxe_install/arm64/estuary/${version_name}/${distro_name}/${DEVICE_TYPE,,}/" && cd -

            # update pxe grub setting
            cp -f "${script_path}/../configs/auto-install/${distro_name}/auto-pxe/grub.cfg" ./
            sed -i 's/${template}/'"${version_name}"'/g' grub.cfg
            sed -i 's/${device}/'"${DEVICE_TYPE,,}"'/g' grub.cfg
            rm -rf netboot netboot.tar.gz || true

            wget -c -q ${FTP_SERVER}/open-estuary/${version_name}/"${os_dict[$distro_name]}"/netboot.tar.gz
            tar -xzvf netboot.tar.gz
        fi
        if timeout 60 sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${NEXT_SERVER} test -d "/var/lib/lava/dispatcher/tmp/pxe_install/arm64/estuary/${version_name}/${distro_name}/${DEVICE_TYPE,,}/";then
            timeout 60 sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${NEXT_SERVER} mkdir -p "/var/lib/lava/dispatcher/tmp/pxe_install/arm64/estuary/${version_name}/${distro_name}/${DEVICE_TYPE,,}/"
            timeout 60 scp -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r "/tftp/pxe_install/arm64/estuary/template/${distro_name}/${DEVICE_TYPE,,}/" root@${NEXT_SERVER}:"/var/lib/lava/dispatcher/tmp/pxe_install/arm64/estuary/${version_name}/${distro_name}/${DEVICE_TYPE,,}/"
        fi
    fi
}


function config_tftp_iso() {
    # config uefi
    if [ "${tree_name}" = 'linaro' ];then
        :
    elif [ "${tree_name}" = 'open-estuary' ];then
        if [ ! -e "/tftp/iso_install/arm64/estuary/${version_name}/${distro_name}/${DEVICE_TYPE,,}/auto-install.iso" ];then
            mkdir -p "/tftp/iso_install/arm64/estuary/${version_name}/${distro_name}/${DEVICE_TYPE,,}"
            cd "/tftp/iso_install/arm64/estuary/${version_name}/${distro_name}/${DEVICE_TYPE,,}"
            # replave iso
            rm -rf *.iso || true
            init_os_dict
            wget -c -q ${FTP_SERVER}/open-estuary/${version_name}/"${os_dict[$distro_name]}"/auto-install.iso
        fi
        if timeout 60 sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${NEXT_SERVER} test -d "/var/lib/lava/dispatcher/tmp/iso_install/arm64/estuary/${version_name}/${distro_name}/${DEVICE_TYPE,,}/";then
            timeout 60 sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${NEXT_SERVER} mkdir -p "/var/lib/lava/dispatcher/tmp/iso_install/arm64/estuary/${version_name}/${distro_name}/${DEVICE_TYPE,,}/"
            timeout 60 scp -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r "/tftp/iso_install/arm64/estuary/${version_name}/${distro_name}/${DEVICE_TYPE,,}" root@${NEXT_SERVER}:"/var/lib/lava/dispatcher/tmp/iso_install/arm64/estuary/${version_name}/${distro_name}/${DEVICE_TYPE,,}"
        fi
    fi
}


if [ "${BOOT_PLAN}" = "BOOT_PXE" ];then
    config_tftp_pxe "$@"
elif [ "${BOOT_PLAN}" = "BOOT_ISO" ];then
    config_tftp_iso "$@"
fi
