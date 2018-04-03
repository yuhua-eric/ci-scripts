#!/bin/bash -ex
#: Title                  : centos_mkautoiso.sh
#: Usage                  : ./centos_mkautoiso.sh
#: Author                 : qinsl0106@thundersoft.com
#: Description            : 生成 centos auto-install.iso

GIT_DESCRIBE=${1:-"None"}

#material_iso="CentOS-7-aarch64-Everything.iso"
new_iso="auto-install.iso"
cfg_path="../configs/auto-install/centos/auto-iso/"
new_grub="grub.cfg"
new_kickstart="ks-iso.cfg"

VERSION=$(ls /fileserver/open-estuary)
if [ -z ${VERSION} ];then
    exit 1
fi

material_iso=$(ls /fileserver/open-estuary/${VERSION}/CentOS/*CentOS*.iso)
if [ -z "${material_iso}" ];then
    exit 1
fi

if [ ! -d ./mnt ];then
    mkdir ./mnt
else
    umount -l ./mnt/
    rm -rf ./mnt
    mkdir ./mnt
fi

if [ ! -d ./centos ];then
    mkdir ./centos
else
    rm -rf ./centos
    mkdir centos
fi

mount "${material_iso}" ./mnt

cp -rf ./mnt/* ./mnt/.discinfo ./mnt/.treeinfo ./centos/

cp $cfg_path$new_grub ./centos/EFI/BOOT/
cp $cfg_path$new_kickstart ./centos/
# TODO: sed grub and cfg info.
sed -i 's/${template}/'"${GIT_DESCRIBE}"'/g' ./centos/EFI/BOOT/$new_grub || true

genisoimage -e images/efiboot.img -no-emul-boot -T -J -R -c boot.catalog -hide boot.catalog -V "CentOS 7 aarch64" -o ./$new_iso ./centos

umount ./mnt/
rm -rf ./centos ./mnt

cp -f ${new_iso} /fileserver/open-estuary/${VERSION}/CentOS/
