#!/bin/bash -ex
#: Title                  : ubuntu_mkautoiso.sh
#: Usage                  : ./ubuntu_mkautoiso.sh
#: Author                 : qinsl0106@thundersoft.com
#: Description            : 生成 ubuntu auto-install.iso

GIT_DESCRIBE=${1:-"None"}

#material_iso="estuary-master-ubuntu.iso"
new_iso="auto-install.iso"
cfg_path="../configs/auto-install/ubuntu/auto-iso/"
new_grub="grub.cfg"
new_preseed="ubuntu.seed"

VERSION=$(ls /home/fileserver/open-estuary)
if [ -z ${VERSION} ];then
    exit 1
fi

# find the iso path
material_iso=$(ls /home/fileserver/open-estuary/${VERSION}/Ubuntu/*everything*.iso)
if [ -z "${material_iso}" ];then
    exit 1
fi

if [ ! -d ./mnt ];then
    mkdir ./mnt
else
    umount -l ./mnt/ || true
    rm -rf ./mnt
    mkdir ./mnt
fi

if [ ! -d ./ubuntu ];then
    mkdir ./ubuntu
else
    rm -rf ./ubuntu
    mkdir ubuntu
fi

mount "${material_iso}" ./mnt

cp -rf ./mnt/* ./mnt/.disk/ ./ubuntu/

cp $cfg_path$new_grub ./ubuntu/boot/grub/
cp $cfg_path$new_preseed ./ubuntu/preseed/
# TODO: sed grub and cfg info.
sed -i 's/${template}/'"${GIT_DESCRIBE}"'/g' ./ubuntu/boot/grub/$new_grub || true


xorriso -as mkisofs -r -V 'custom' -o ./$new_iso -J -joliet-long -e boot/grub/efi.img -no-emul-boot ubuntu/

umount ./mnt/
rm -rf ./ubuntu ./mnt

cp -f ${new_iso} /home/fileserver/open-estuary/${VERSION}/Ubuntu/
