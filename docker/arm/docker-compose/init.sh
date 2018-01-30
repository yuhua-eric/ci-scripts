#!/bin/bash -e

source .env

if [ -z "${WORK_HOME}" ];then
    echo "error : must have WORK_HOME variable!"
    exit 1
fi

mkdir -p ${WORK_HOME}
cd ${WORK_HOME}

if [ ! -d "${WORK_HOME}/fileserver_data" ];then
    mkdir -p ${WORK_HOME}/fileserver_data
    chmod a+rwx ${WORK_HOME}/fileserver_data
fi

if [ ! -d "${WORK_HOME}/tftp_nfs_data" ];then
    mkdir -p ${WORK_HOME}/tftp_nfs_data
    chmod a+rwx ${WORK_HOME}/tftp_nfs_data
    sudo chown nobody:nogroup ${WORK_HOME}/tftp_nfs_data
    if [ ! -d "/var/lib/lava/dispatcher/tmp" ];then
        # install nfs
        sudo apt-get install -yq nfs-kernel-server
        sudo mkdir -p /var/lib/lava/dispatcher/
        cd /var/lib/lava/dispatcher
        sudo ln -s  ${WORK_HOME}/tftp_nfs_data tmp
        cd -
        sudo echo "/var/lib/lava/dispatcher/tmp *(rw,no_root_squash,no_all_squash,async,no_subtree_check)" >  /etc/exports
        sudo exportfs -ra && service nfs-kernel-server start
    fi
fi

if [ ! -d "${WORK_HOME}/jenkins_data/" ];then
    # download jenkins home
    curl -k -u 'estuary':'estuary12#$' 'http://192.168.67.50/remote.php/webdav/docker-configs/'"jenkins_data.tar.gz" -o "jenkins_data.tar.gz"
    #curl -k -u 'estuary':'estuary12#$' 'http://nj.thundersoft.com:8030/remote.php/webdav/docker-configs/'"jenkins_data.tar.gz" -o "jenkins_data.tar.gz"

    tar -xzvf "jenkins_data.tar.gz"
fi

if [ ! -d "${WORK_HOME}/lava_data/" ];then
    # download jenkins home
    curl -k -u 'estuary':'estuary12#$' 'http://192.168.67.50/remote.php/webdav/docker-configs/'"lava_data.tar.gz" -o "lava_data.tar.gz"
    # curl -k -u 'estuary':'estuary12#$' 'http://nj.thundersoft.com:8030/remote.php/webdav/docker-configs/'"lava_data.tar.gz" -o "lava_data.tar.gz"
    sudo tar -xzvf "lava_data.tar.gz"
fi

if [ ! -d "${WORK_HOME}/compile_data" ];then
    # mkdir compile data.
    mkdir -p ${WORK_HOME}/compile_data
    chmod a+rwx ${WORK_HOME}/compile_data
fi


if [ ! -d "${WORK_HOME}/estuary_reference" ];then
    mkdir -p ${WORK_HOME}/estuary_reference
    chmod a+rwx ${WORK_HOME}/estuary_reference
fi

echo "please run following command to start service : "
echo "docker-compose up -d"

# in huawei test server 192.168.1.108
# ln -s /opt/var/lib/lava/dispatcher/tmp/ tftp_nfs_data
# ln -s /opt/var/lib/lava/dispatcher/tmp/lava_data lava_data
# ln -s /opt/var/lib/lava/dispatcher/tmp/jenkins_data jenkins_data
