#!/bin/bash -ex
#: Title                  : debian_mkautoiso.sh
#: Usage                  : ./debian_mkautoiso.sh
#: Author                 : qinsl0106@thundersoft.com
#: Description            : 生成 debian auto-install.iso

GIT_DESCRIBE=${1:-"None"}

#material_iso="estuary-master-debian-9.0-arm64-CD-1.iso"
new_iso="auto-install.iso"
cfg_path="../configs/auto-install/debian/auto-iso/"
new_grub="grub.cfg"
new_preseed="preseed.cfg"

VERSION=$(ls /home/fileserver/open-estuary)
if [ -z "${VERSION}" ];then
    exit 1
fi

material_iso=$(ls /home/fileserver/open-estuary/${VERSION}/Debian/*debian*.iso)
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

if [ ! -d ./debian ];then
    mkdir ./debian
else
    rm -rf ./debian
    mkdir debian
fi

mount "${material_iso}" ./mnt

cp -rf ./mnt/* ./mnt/.disk/ ./debian/

cp $cfg_path$new_grub ./debian/boot/grub/
cp $cfg_path$new_preseed ./debian/
# TODO: sed grub and cfg info.
sed -i 's/${template}/'"${GIT_DESCRIBE}"'/g' ./debian/boot/grub/$new_grub || true

xorriso -as mkisofs -r -o ./$new_iso -J -joliet-long -e boot/grub/efi.img -no-emul-boot debian/
umount ./mnt/
rm -rf ./debian ./mnt

cp -f ${new_iso} /home/fileserver/open-estuary/${VERSION}/Debian/
