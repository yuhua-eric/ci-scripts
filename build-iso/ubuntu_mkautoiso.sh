#!/bin/bash

material_iso="estuary-master-ubuntu.iso"
new_iso="auto-estuary-master-ubuntu.iso"
cfg_path="./auto_cfg_file/"
new_grub="grub.cfg"
new_preseed="ubuntu.seed"

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

mount $material_iso ./mnt

cp -rf ./mnt/* ./mnt/.disk/ ./ubuntu/

cp $cfg_path$new_grub ./ubuntu/boot/grub/
cp $cfg_path$new_preseed ./ubuntu/preseed/

xorriso -as mkisofs -r -checksum_algorithm_iso md5,sha1 -V 'custom' -o ./$new_iso -J -joliet-long -cache-inodes -e boot/grub/efi.img -no-emul-boot -append_partition 2 0xef ubuntu/boot/grub/efi.img  -partition_cyl_align all ubuntu/

umount ./mnt/
rm -rf ./ubuntu ./mnt
