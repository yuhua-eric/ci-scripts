#!/bin/bash -ex

# prepare system tools
function prepare_tools() {
    dev_tools="sshpass ipmitool"

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
    # config dhcp
    :
}

function config_tftp() {
    # config dhcp
    :
}

function do_deploy() {
    # do deploy
    pushd ${CI_SCRIPTS_DIR}/deploy-scripts
    python deploy.py
    popd
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

    config_dhcp
    config_tftp
    do_deploy

    save_to_properties
}

main "$@"
