#!/bin/bash -ex
#: Title                  : ubuntu_mkautoiso.sh
#: Usage                  : ./ubuntu_mkautoiso.sh
#: Author                 : qinsl0106@thundersoft.com
#: Description            : 生成 ubuntu auto-install.iso

#material_iso="estuary-master-ubuntu.iso"
new_iso="auto-install.iso"
cfg_path="../configs/auto-install/ubuntu/auto-iso/"
new_grub="grub.cfg"
new_preseed="ubuntu.seed"

VERSION=$(ls /fileserver/open-estuary)
if [ -z ${VERSION} ];then
    exit 1
fi

# find the iso path
material_iso=$(ls /fileserver/open-estuary/${VERSION}/Ubuntu/*ubuntu*.iso)
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

xorriso -as mkisofs -r -checksum_algorithm_iso md5,sha1 -V 'custom' -o ./$new_iso -J -joliet-long -cache-inodes -e boot/grub/efi.img -no-emul-boot -append_partition 2 0xef ubuntu/boot/grub/efi.img  -partition_cyl_align all ubuntu/

umount ./mnt/
rm -rf ./ubuntu ./mnt

cp -f ${new_iso} /fileserver/open-estuary/${VERSION}/Ubuntu/
