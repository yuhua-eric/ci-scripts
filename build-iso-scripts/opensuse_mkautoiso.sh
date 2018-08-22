#!/bin/bash
#: Title                  : opensuse_mkautoiso.sh
#: Usage                  : ./opensuse_mkautoiso.sh
#: Author                 : yu_hua1@hoperun.com
#: Description            : 生成 opensuse auto-install.iso
set -ex

GIT_DESCRIBE=${1:-"None"}

new_iso="auto-install.iso"
cfg_path="../configs/auto-install/opensuse/auto-iso/"
new_grub="grub.cfg"
#new_kickstart="ks-iso.cfg"
new_xml="autoinst-iso.xml"
#WORKSPACE=${WORKSPACE:-/home/jenkins/workspace/Estuary-Test}
WORKSPACE_NAME=${1:-"Estuary-Test"}
cu_dir="/root/jenkins/workspace/${WORKSPACE_NAME}/local/ci-scripts/build-iso-scripts"
cd $cu_dir
#VERSION=$(ls /fileserver/open-estuary)
#if [ -z ${VERSION} ];then
#    exit 1
#fi

#material_iso=$(ls /fileserver/open-estuary/${VERSION}/OpenSuse/*openSUSE*.iso)
material_iso=$(ls ./*openSUSE*.iso)
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

if [ ! -d ./opensuse ];then
    mkdir ./opensuse
else
    rm -rf ./opensuse
    mkdir opensuse
fi

mount "${material_iso}" ./mnt

cp -rf ./mnt/* ./opensuse/

#cp $cfg_path$new_grub ./opensuse/EFI/BOOT/
# TODO: sed grub and cfg info.
#sed -i 's/${template}/'"${GIT_DESCRIBE}"'/g' ./opensuse/EFI/BOOT/$new_grub || true

## modify:add kickstart file into initrd
rm -rf initr
mkdir -p initr
cp ./opensuse/boot/aarch64/initrd ./
cd initr
xzcat ../initrd | cpio -idmv
rm ../initrd
cp -f ../$cfg_path$new_xml ./autoinst.xml
find . | cpio -o -H newc | xz --check=crc32 --lzma2=dict=512KiB > ../initrd
cd ..
cp ./initrd ./opensuse/boot/aarch64/
##end of modify

mksusecd --create ./$new_iso --no-hybrid ./opensuse

umount ./mnt/
rm -rf ./opensuse ./mnt ./initrd ./initr/
#cp -f ${new_iso} /fileserver/open-estuary/${VERSION}/Opensuse/

