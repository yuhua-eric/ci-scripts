#!/bin/bash -ex

material_iso="estuary-master-debian-9.0-arm64-CD-1.iso"
new_iso="auto-install.iso"
cfg_path="../configs/auto-install/debian/auto-iso/"
new_grub="grub.cfg"
new_preseed="preseed.cfg"

VERSION=$(ls /fileserver/open-estuary)
if [ -z ${VERSION} ];then
    exit 1
fi
cp -f /fileserver/open-estuary/${VERSION}/Debian/${material_iso} ./

if [ ! -d ./mnt ];then
    mkdir ./mnt
else
    umount -l ./mnt/
    rm -rf ./mnt
    mkdir ./mnt
fi

if [ ! -d ./debian ];then
    mkdir ./debian
else
    rm -rf ./debian
    mkdir debian
fi

mount $material_iso ./mnt

cp -rf ./mnt/* ./mnt/.disk/ ./debian/

cp $cfg_path$new_grub ./debian/boot/grub/
cp $cfg_path$new_preseed ./debian/


xorriso -as mkisofs -r -checksum_algorithm_iso md5,sha1 -o ./$new_iso -J -joliet-long -cache-inodes -e boot/grub/efi.img -no-emul-boot -append_partition 2 0xef debian/boot/grub/efi.img -partition_cyl_align all debian/

umount ./mnt/
rm -rf ./debian ./mnt

cp -f ${new_iso} /fileserver/open-estuary/${VERSION}/Debian/
