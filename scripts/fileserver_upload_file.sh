#!/bin/bash -e
# http://120.31.149.194:18083/upload_data/

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

echo "http://120.31.149.194:18083/upload_data/${TODAY}/${UUID}/${FILENAME}"
echo "http://192.168.50.122:8083/upload_data/${TODAY}/${UUID}/${FILENAME}"

mkdir -p ${WORKSPACE}/html_result/
cat > ${WORKSPACE}/html_result/index.html <<-EOF
<p>File have been upload: <a href="http://120.31.149.194:18083/upload_data/${TODAY}/${UUID}/${FILENAME}">http://120.31.149.194:18083/upload_data/${TODAY}/${UUID}/${FILENAME}</a> </p>
<p>You can access this file by this link in CI enviroment: <a href="http://192.168.50.122:8083/upload_data/${TODAY}/${UUID}/${FILENAME}">http://192.168.50.122:8083/upload_data/${TODAY}/${UUID}/${FILENAME}</a></p>
<p>Download Commandline:</p>
<pre>
  wget http://192.168.50.122:8083/upload_data/${TODAY}/${UUID}/${FILENAME}
</pre>
EOF
