#!/bin/bash -ex

UPLOAD_DIR="/fileserver/upload_data"

if [ -z "${FILENAME}" ];then
    exit 1
fi

cd "${UPLOAD_DIR}"

TODAY=$(date +"%Y%m%d")
UUID=$(dbus-uuidgen)
mkdir -p "${TODAY}/${UUID}"

cd "${TODAY}/${UUID}"
cp ${WORKSPACE}/data.tar.gz ./${FILENAME}
