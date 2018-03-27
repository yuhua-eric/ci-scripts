#!/bin/bash -ex
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

echo "http://192.168.50.122:8083/upload_data/${TODAY}/${UUID}/${FILENAME}"

cat > index.html <<-EOF
<p>文件已经上传到该路径 <a href=\"http://120.31.149.194:18083/upload_data/${TODAY}/${UUID}/${FILENAME}\">http://120.31.149.194:18083/upload_data/${TODAY}/${UUID}/${FILENAME}</a> </p>
<p>你可以通过该连接在CI内网访问 <a href=\"http://192.168.50.122:8083/upload_data/${TODAY}/${UUID}/${FILENAME}\">http://192.168.50.122:8083/upload_data/${TODAY}/${UUID}/${FILENAME}</a></p>
<p>你可以通过以下命令在命令行下载该文件:</p>
<pre>
  wget http://192.168.50.122:8083/upload_data/${TODAY}/${UUID}/${FILENAME}
</pre>
EOF
