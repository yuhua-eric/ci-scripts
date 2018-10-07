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
#  E-mail    :    yu_hua1@hoperun.com

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
function parse_params() {
    WORKSPACE=${WORKSPACE:-/home/jenkins/workspace/Estuary-Test}
    WORK_DIR=${WORKSPACE}/local
    WORKSPACE_NAME=`echo $WORKSPACE |sed 's:/: :g'|awk  '{print $4}'`
    CI_SCRIPTS_DIR=${WORK_DIR}/ci-scripts
    OPEN_ESTUARY_DIR=${WORK_DIR}/open-estuary
    pushd ${CI_SCRIPTS_DIR}
    : ${SHELL_DISTRO:=`python configs/parameter_parser.py -f config.yaml -s Build -k Distro`}
    : ${ALL_SHELL_DISTRO:=`python configs/parameter_parser.py -f config.yaml -s Build -k Distro`}
    : ${TARGET_IP:=`python configs/parameter_parser.py -f config.yaml -s DHCP -k ip`}
    popd    # restore current work directory
}
function deal_with_iso() {
    VERSION=$(ls /home/fileserver/open-estuary)
    if [ -z ${VERSION} ];then
        exit 1
    fi
    cd /home/fileserver/open-estuary/${VERSION}
    if [ x"$SAVE_ISO" = x"n" ]; then
        for DISTRO in $ALL_SHELL_DISTRO;do
            if [ x"$DISTRO" = x"CentOS" -o x"$DISTRO" = x"Fedora" ]; then
                cd $DISTRO && rm -f *$DISTRO*.iso && cd -
            elif [ x"$DISTRO" = x"Ubuntu" -o x"$DISTRO" = x"Debian" ]; then
                distro="$(echo $DISTRO | tr '[:upper:]' '[:lower:]')"
                cd $DISTRO && rm -f *$distro*.iso && cd -
            elif [ x"$DISTRO" = x"OpenSuse" ]; then
                cd OpenSuse && rm -f *openSUSE*.iso && cd -
            fi
        done
        #cd OpenSuse && rm -f *openSUSE*.iso && cd -
    fi
 }

function scp_build_result() {

    local SSH_PASS="root"
    local SSH_USER=root
    local SSH_IP=${TARGET_IP}
    target_dir=$(ls /home/fileserver/open-estuary/)
    if timeout 120 sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${TARGET_IP} test -d "/mnt/data/fileserver_data/open-estuary/${target_dir}";then
        echo  "/mnt/data/fileserver_data/open-estuary/${target_dir} exist in ${TARGET_IP}"
    else
        sshpass -p 'root' scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r "/home/fileserver/open-estuary/*" root@${TARGET_IP}:"/mnt/data/fileserver_data/open-estuary/" &
        sleep 3m
        wait
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
    rm -f ./*openSUSE*.iso
}
function main() {
    parse_input "$@"
    source_properties_file "${PROPERTIES_FILE}"
    init_input_params
    parse_params
    #start_docker_service
    for DISTRO in $ALL_SHELL_DISTRO;do
	cat $OPEN_ESTUARY_DIR/estuary/compile_result.txt |sed -n "/${DISTRO,,}:pass/p" > ./compile_tmp.log
        if [ -s ./compile_tmp.log ] ; then
            distro="$(echo $DISTRO | tr '[:upper:]' '[:lower:]')"
            if [ x"$distro" != x"opensuse" ]; then            
                ./${distro}_mkautoiso.sh "${GIT_DESCRIBE}"
            else
                start_docker_service
                cp_opensuse_iso
                docker run --privileged=true -i -v /home:/root/ --name opensuse estuary/opensuse:5.1-full bash /root/jenkins/workspace/${WORKSPACE_NAME}/local/ci-scripts/build-iso-scripts/opensuse_mkautoiso.sh ${WORKSPACE_NAME}
                cp_auto_iso
            fi
	fi
    done
    deal_with_iso
}

main "$@"
