#!/bin/bash -ex
#: Title                  : common.sh
#: Usage                  : source common.sh
#: Author                 : qinsl0106@thundersoft.com
#: Description            : 部署部分公共方法

function init_os_dict() {
    # declare global dict
    declare -A -g os_dict
    os_dict=( ["centos"]="CentOS" ["ubuntu"]="Ubuntu" ["debian"]="Debian" ["fedora"]="Fedora" ["opensuse"]="Opensuse")
}
