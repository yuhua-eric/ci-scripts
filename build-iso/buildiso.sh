#!/bin/bash -ex
VERSION=$1

if [ -z ${VERSION} ];then
    exit 1
fi

./centos_mkautoiso.sh

./ubuntu_mkautoiso.sh
