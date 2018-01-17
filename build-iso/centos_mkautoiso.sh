#!/bin/bash -ex

material_iso="CentOS-7-aarch64-Everything.iso"
new_iso="auto-CentOS-7-aarch64-Everything.iso"
cfg_path="./auto_cfg_file/centos/"
new_grub="grub.cfg"
new_kickstart="ks-iso.cfg"

cp /fileserver/open-estuary/${VERSION}/CentOS/${material_iso} ./

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

mount $material_iso ./mnt

cp -rf ./mnt/* ./mnt/.discinfo ./mnt/.treeinfo ./centos/

cp $cfg_path$new_grub ./centos/EFI/BOOT/
cp $cfg_path$new_kickstart ./centos/

genisoimage -e images/efiboot.img -no-emul-boot -T -J -R -c boot.catalog -hide boot.catalog -V "CentOS 7 aarch64" -o ./$new_iso ./centos

umount ./mnt/
rm -rf ./centos ./mnt

cp ${new_iso} /fileserver/open-estuary/${VERSION}/CentOS/
