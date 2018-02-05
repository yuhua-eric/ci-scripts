#!/bin/bash -ex
#: Title                  : common.sh
#: Usage                  : source common.sh
#: Author                 : qinsl0106@thundersoft.com
#: Description            : 部署部分公共方法

function workaround_stash_devices_config() {
    if [ -n "${CI_ENV}" ];then
        :
    else
        CI_ENV=dev
    fi
    if [ -e "configs/"${CI_ENV}"/devices.yaml" ];then
        cp -f configs/"${CI_ENV}"/devices.yaml /tmp/devices.yaml
    fi
}

function workaround_pop_devices_config() {
    if [ -n "${CI_ENV}" ];then
        :
    else
        CI_ENV=dev
    fi

    if [ -e "/tmp/devices.yaml" ];then
        cp -f /tmp/devices.yaml configs/"${CI_ENV}"/devices.yaml
    fi
}

function init_os_dict() {
    # declare global dict
    declare -A -g os_dict
    os_dict=( ["centos"]="CentOS" ["ubuntu"]="Ubuntu" ["debian"]="Debian")
}
