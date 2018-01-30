#!/bin/bash
# https://docs.docker.com/engine/admin/multi-service_container/
service_check () {
    if [ "$#" = 0 ];then
        echo "ERROR: don't have any process need check."
        exit -1
    fi

    while /bin/true; do
        for process in "$@";do
            sleep 60
            if (( $(ps -ef | grep -v grep | grep "$process" | wc -l) == 0 )); then
                echo "processe has exited."
                exit -1
            fi
        done
    done
}

service_check apache2
