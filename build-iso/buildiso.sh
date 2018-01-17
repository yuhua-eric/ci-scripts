#!/bin/bash -ex
VERSION=$1

cd /fileserver/open-estuary

if [ -z ${VERSION} ];then
    exit 1
fi

cd ${VERSION}

cd CentOS
# CentOS-7-aarch64-Everything.iso
./centos_mkautoiso.sh

cd Ubuntu
# estuary-master-ubuntu.iso
./ubuntu_mkautoiso.sh
