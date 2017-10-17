#!/bin/bash -ex

# prepare system tools
function prepare_tools() {
    dev_tools="sshpass ipmitool python-pip python-pexpect"

    if ! (dpkg-query -l $dev_tools >/dev/null 2>&1); then
        sudo apt-get update
        if ! (sudo apt-get install -y --force-yes $dev_tools); then
            echo "ERROR: can't install tools: ${dev_tools}"
            exit 1
        fi
    fi
}

# jenkins job debug variables
function init_deploy_option() {
    SKIP_DEPLOY=${SKIP_DEPLOY:-"false"}
    SKIP_UEFI=${SKIP_UEFI:-"true"}

    DHCP_CONFIG_DIR=/etc/dhcp
    DHCP_SERVER=192.168.30.2
    DHCP_FILENAME=dhcpd.conf

    TFTP_DIR=/tftp

    TFTP_ESTUARY_GRUB=grub.cfg
    TFTP_LINARO_GRUB=linaro_install/grub.cfg
}

# ensure workspace exist
function init_workspace() {
    WORKSPACE=${WORKSPACE:-/home/ts/jenkins/workspace/estuary-ci}
    mkdir -p ${WORKSPACE}
}

# init sub dirs path
function init_env_params() {
    WORK_DIR=${WORKSPACE}/local
    CI_SCRIPTS_DIR=${WORK_DIR}/ci-scripts
}

function init_build_env() {
    LANG=C
    PATH=${CI_SCRIPTS_DIR}/build-scripts:$PATH

    CPU_NUM=$(cat /proc/cpuinfo | grep processor | wc -l)
    OPEN_ESTUARY_DIR=${WORK_DIR}/open-estuary
    BUILD_DIR=${OPEN_ESTUARY_DIR}/build
    ESTUARY_CFG_FILE=${OPEN_ESTUARY_DIR}/estuary/estuarycfg.json
}


function init_input_params() {
    # project name
    TREE_NAME=${TREE_NAME:-"open-estuary"}

    # select a version
    VERSION=${VERSION:-""}

    GIT_DESCRIBE=${GIT_DESCRIBE:-""}

    # select borad
    SHELL_PLATFORM=${SHELL_PLATFORM:-""}
    SHELL_DISTRO=${SHELL_DISTRO:-""}


    # test plan
    BOOT_PLAN=${BOOT_PLAN:-"BOOT_NFS"}
    APP_PLAN=${APP_PLAN:-"TEST"}

    # preinstall packages
    PACKAGES=${PACKAGES:-""}

    # all setup types
    SETUP_TYPE=${SETUP_TYPE:-""}

    # only read from config file
    ARCH_MAP=${ARCH_MAP:-""}
}

function parse_params() {
    pushd ${CI_SCRIPTS_DIR}
    : ${SHELL_PLATFORM:=`python parameter_parser.py -f config.yaml -s Build -k Platform`}
    : ${SHELL_DISTRO:=`python parameter_parser.py -f config.yaml -s Build -k Distro`}

    : ${BOOT_PLAN:=`python parameter_parser.py -f config.yaml -s Jenkins -k Boot`}
    : ${APP_PLAN:=`python parameter_parser.py -f config.yaml -s Jenkins -k App`}

    : ${LAVA_SERVER:=`python parameter_parser.py -f config.yaml -s LAVA -k lavaserver`}
    : ${LAVA_USER:=`python parameter_parser.py -f config.yaml -s LAVA -k lavauser`}
    : ${LAVA_STREAM:=`python parameter_parser.py -f config.yaml -s LAVA -k lavastream`}
    : ${LAVA_TOKEN:=`python parameter_parser.py -f config.yaml -s LAVA -k TOKEN`}

    : ${FTP_SERVER:=`python parameter_parser.py -f config.yaml -s Ftpinfo -k ftpserver`}
    : ${FTP_DIR:=`python parameter_parser.py -f config.yaml -s Ftpinfo -k FTP_DIR`}

    : ${ARCH_MAP:=`python parameter_parser.py -f config.yaml -s Arch`}

    popd    # restore current work directory
}

function generate_failed_mail(){
    cd ${WORKSPACE}
    echo "qinsl0106@thundersoft.com,zhangbp0704@thundersoft.com" > MAIL_LIST.txt
    echo "Estuary CI - ${GIT_DESCRIBE} - Failed" > MAIL_SUBJECT.txt
    cat > MAIL_CONTENT.txt <<EOF
( This mail is send by Jenkins automatically, don't reply )
Project Name: ${TREE_NAME}
Version: ${GIT_DESCRIBE}
Build Status: failed
Boot and Test Status: failed
Build Log Address: ${BUILD_URL}console
Build Project Address: $BUILD_URL
Build and Generated Binaries Address: NONE
The Test Cases Definition Address: https://github.com/qinshulei/ci-test-cases

The deploy is failed unexpectly. Please check the log and fix it.

EOF

}

function save_to_properties() {
    cat << EOF > ${WORKSPACE}/env.properties
TREE_NAME="${TREE_NAME}"
GIT_DESCRIBE="${GIT_DESCRIBE}"
SHELL_PLATFORM="${SHELL_PLATFORM}"
SHELL_DISTRO="${SHELL_DISTRO}"
BOOT_PLAN="${BOOT_PLAN}"
APP_PLAN="${APP_PLAN}"
ARCH_MAP="${ARCH_MAP}"
EOF
    # EXECUTE_STATUS="Failure"x
    cat ${WORKSPACE}/env.properties
}

function show_properties() {
    cat ${WORKSPACE}/env.properties
}

function print_time() {
    init_timefile
    echo  $@ `date "+%Y-%m-%d %H:%M:%S"` >> $timefile
}

function init_timefile() {
    timefile=${WORKSPACE}/timestamp.log
    if [ -f $timefile ]; then
        rm -fr $timefile
    else
        touch $timefile
    fi
}

function parse_arch_map(){
    read -a arch_map <<< $(echo $ARCH_MAP)
    declare -A -g arch
    for((i=0; i<${#arch_map[@]}; i++)); do
        if ((i%2==0)); then
            j=`expr $i+1`
            arch[${arch_map[$i]}]=${arch_map[$j]}
        fi
    done
}

function show_help(){
    :
}

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
            p)  properties_file=$OPTARG
                ;;
        esac
    done

    shift $((OPTIND-1))

    [ "$1" = "--" ] && shift

    echo "properties_file='$properties_file', Leftovers: $@"
}

# used to load paramters in pipeline job.
function source_properties_file() {
    if [ -n "${properties_file}" ];then
        if [ -e "${properties_file}" ];then
            source "${properties_file}"
        fi
    fi
}

function config_dhcp() {
    local tree_name="$1"
    # config dhcp
    if [ "${tree_name}" = 'linaro' ];then
        sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.30.2 cp -f /etc/dhcp/examples/dhcpd.conf.linaro /etc/dhcp/dhcpd.conf
    elif [ "${tree_name}" = 'open-estuary' ];then
        sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.30.2 cp -f /etc/dhcp/examples/dhcpd.conf.estuary /etc/dhcp/dhcpd.conf
    fi

    sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.30.2 service isc-dhcp-server restart
}

function config_uefi() {
    # config tftp
    local tree_name="$1"
    if [ "${tree_name}" = 'linaro' ];then
        # do deploy
        pushd ${CI_SCRIPTS_DIR}/deploy-scripts
        python update_uefi.py --uefi UEFI_D05_linaro_16_12.fd
        popd
    elif [ "${tree_name}" = 'open-estuary' ];then
        # do deploy
        pushd ${CI_SCRIPTS_DIR}/deploy-scripts
        python update_uefi.py --uefi UEFI_D05_Estuary.fd
        popd
    fi
}

function config_tftp() {
    local tree_name="$1"
    # config uefi
    if [ "${tree_name}" = 'linaro' ];then
        cp -f /tftp/linaro_install/CentOS/linaro_centos.grub.cfg /tftp/linaro_install/grub.cfg
    elif [ "${tree_name}" = 'open-estuary' ];then
        cp -f /tftp/estuary_install/grub.cfg /tftp/grub.cfg
    fi
}

function do_deploy() {
    # do deploy
    pushd ${CI_SCRIPTS_DIR}/deploy-scripts
    python deploy.py
    popd

    copy_ssh_id
}

function copy_ssh_id(){
    SSH_PASS=root
    SSH_USER=root
    SSH_IP=192.168.30.201

    sshpass -p ${SSH_PASS} ssh-copy-id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${SSH_IP}

}

function main() {
    parse_input "$@"
    source_properties_file

    prepare_tools

    init_deploy_option
    init_workspace
    init_env_params
    init_build_env

    init_input_params
    parse_params

    save_to_properties
    show_properties

    generate_failed_mail

    print_time "the begin time is "
    parse_arch_map

    config_dhcp "${TREE_NAME}"
    config_tftp "${TREE_NAME}"
    if [ x"${SKIP_UEFI}" = x"true" ];then
        echo "skip update uefi!"
    else
        config_uefi "${TREE_NAME}"
    fi

    if [ "${BOOT_PLAN}" = "BOOT_PXE" ];then
        if [ x"${SKIP_DEPLOY}" = x"true" ];then
            echo "skip deploy!"
        else
            do_deploy
        fi
    fi

    save_to_properties
}

main "$@"
