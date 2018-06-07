#!/bin/bash -ex
# depends:
# ubuntu
# apt-get install genisoimage
# apt-get install xorriso
# centos
# yum install genisoimage
# wget https://www.gnu.org/software/xorriso/xorriso-1.4.8.tar.gz
# tar -xzvf xorriso-1.4.8.tar.gz
# ./configure && make && make install

__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
source "${script_path}/../common-scripts/common.sh"

function parse_input() {
    # A POSIX variable
    OPTIND=1         # Reset in case getopts has been used previously in the shell.

    # Initialize our own variables:
    properties_file=""

    while getopts "h?p:" opt; do
        case "$opt" in
            h|\?)
                show_help
                exit 0
                ;;
            p)  PROPERTIES_FILE=$OPTARG
                ;;
        esac
    done

    shift $((OPTIND-1))

    [ "$1" = "--" ] && shift

    echo "properties_file='$properties_file', Leftovers: $@"
}

function init_input_params() {
    TREE_NAME=${TREE_NAME:-"open-estuary"}
    GIT_DESCRIBE=${GIT_DESCRIBE:-""}
    SAVE_ISO=${SAVE_ISO:-"n"}
}
function deal_with_iso() {
    VERSION=$(ls /home/fileserver/open-estuary)
    if [ -z ${VERSION} ];then
        exit 1
    fi
    cd /home/fileserver/open-estuary/${VERSION}
    if [ x"$SAVE_ISO" = x"n" ]; then
        cd CentOS && rm -f *CentOS*.iso && cd -
        cd Ubuntu && rm -f *ubuntu*.iso && cd -
        cd Debian && rm -f *debian*.iso && cd -
        cd Fedora && rm -f *Fedora*.iso && cd -
        #cd OpenSuse && rm -f *openSUSE*.iso && cd -
    fi
}

function start_docker_service() {
    docker_status=`service docker status|grep "running"`
    if [ x"$docker_status" = x"" ]; then
        service docker start
    fi
}

function cp_opensuse_iso(){
    VERSION=$(ls /home/fileserver/open-estuary)
    if [ -z ${VERSION} ];then
        exit 1
    fi 
    material_iso=$(ls /home/fileserver/open-estuary/${VERSION}/OpenSuse/*openSUSE*.iso)
    cp ${material_iso} ./
}

function cp_auto_iso(){
    VERSION=$(ls /home/fileserver/open-estuary)
    if [ -z ${VERSION} ];then
        exit 1
    fi
    cp -f ./auto-install.iso /home/fileserver/open-estuary/${VERSION}/OpenSuse/
}
function main() {
    parse_input "$@"
    source_properties_file "${PROPERTIES_FILE}"
    init_input_params
    #start_docker_service
    ./centos_mkautoiso.sh "${GIT_DESCRIBE}"
    ./ubuntu_mkautoiso.sh "${GIT_DESCRIBE}"
    ./debian_mkautoiso.sh "${GIT_DESCRIBE}"
    ./fedora_mkautoiso.sh "${GIT_DESCRIBE}"
    #./opensuse_mkautoiso.sh "${GIT_DESCRIBE}"
    #cp_opensuse_iso
    #docker run --privileged=true -i -v /home:/root/ --name opensuse estuary/opensuse:5.1-full bash /root/jenkins/workspace/estuary-v500-build/local/ci-scripts/build-iso-scripts/opensuse_mkautoiso.sh
    #cp_auto_iso
    deal_with_iso
}

main "$@"
