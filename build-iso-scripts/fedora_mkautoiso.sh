#!/bin/bash -ex
#: Title                  : fedora_mkautoiso.sh
#: Usage                  : ./fedora_mkautoiso.sh
#: Author                 : yu_hua1@hoperun.com
#: Description            : 生成 fedora auto-install.iso

GIT_DESCRIBE=${1:-"None"}

#material_iso="CentOS-7-aarch64-Everything.iso"
new_iso="auto-install.iso"
cfg_path="../configs/auto-install/fedora/auto-iso/"
new_grub="grub.cfg"
new_kickstart="ks-iso.cfg"

VERSION=$(ls /home/fileserver/open-estuary)
if [ -z ${VERSION} ];then
    exit 1
fi

material_iso=$(ls /home/fileserver/open-estuary/${VERSION}/Fedora/*everything*.iso)
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

if [ ! -d ./fedora ];then
    mkdir ./fedora
else
    rm -rf ./fedora
    mkdir fedora
fi

mount "${material_iso}" ./mnt

cp -rf ./mnt/* ./mnt/.discinfo ./mnt/.treeinfo ./fedora/

cp $cfg_path$new_grub ./fedora/EFI/BOOT/
# TODO: sed grub and cfg info.
sed -i 's/${template}/'"${GIT_DESCRIBE}"'/g' ./fedora/EFI/BOOT/$new_grub || true

## modify:add kickstart file into initrd
rm -rf initrd
mkdir -p initrd
cp ./fedora/images/pxeboot/initrd.img ./
cd initrd
xzcat ../initrd.img | cpio -idmv
rm ../initrd.img
cp ../$cfg_path$new_kickstart ./
find . | cpio -o -H newc | xz --check=crc32 --lzma2=dict=512KiB > ../initrd.img
cd ..
cp ./initrd.img ./fedora/images/pxeboot/
##end of modify

genisoimage -e images/efiboot.img -no-emul-boot -T -J -R -c boot.catalog -hide boot.catalog -V "Fedora-S-dvd-aarch64-26" -o ./$new_iso ./fedora

umount ./mnt/
rm -rf ./fedora ./mnt ./initrd.img ./initrd/

cp -f ${new_iso} /home/fileserver/open-estuary/${VERSION}/Fedora/
