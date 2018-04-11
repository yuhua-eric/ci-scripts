#!/bin/bash -ex

# backup old cfg
# centos
cp ./configs/auto-install/centos/auto-pxe/anaconda-ks.cfg /fileserver/estuary_v500/CentOS/mirror/anaconda-ks.cfg
cp ./configs/auto-install/centos/auto-pxe/grub.cfg /tftp/pxe_install/arm64/estuary/template/centos/d03/grub.cfg
cp ./configs/auto-install/centos/auto-pxe/grub.cfg /tftp/pxe_install/arm64/estuary/template/centos/d05/grub.cfg

# debian
cp ./configs/auto-install/debian/auto-pxe/grub.cfg /tftp/pxe_install/arm64/estuary/template/debian/d03/grub.cfg
cp ./configs/auto-install/debian/auto-pxe/grub.cfg /tftp/pxe_install/arm64/estuary/template/debian/d05/grub.cfg
cp ./configs/auto-install/debian/auto-pxe/preseed.cfg /fileserver/estuary_v500/Debian/preseed.cfg

# ubuntu
cp ./configs/auto-install/ubuntu/auto-pxe/grub.cfg /tftp/pxe_install/arm64/estuary/template/ubuntu/d03/grub.cfg
cp ./configs/auto-install/ubuntu/auto-pxe/grub.cfg /tftp/pxe_install/arm64/estuary/template/ubuntu/d05/grub.cfg
cp ./configs/auto-install/ubuntu/auto-pxe/ubuntu_ks.cfg /fileserver/estuary_v500/Ubuntu/mirror/ubuntu_ks.cfg
cp ./configs/auto-install/ubuntu/auto-pxe/ubuntu.seed /fileserver/estuary_v500/Ubuntu/mirror/preseed/ubuntu.seed
