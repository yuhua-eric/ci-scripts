#!/bin/bash -ex
# only works on centos

# prepare system tools
function prepare_tools() {
    dev_tools="python-yaml"
    yum install -y ${dev_tools}
}

# jenkins job debug variables
function init_build_option() {
    SKIP_BUILD=${SKIP_BUILD:-"false"}
    SKIP_CP_IMAGE=${SKIP_CP_IMAGE:-"false"}
}

# ensure workspace exist
function init_workspace() {
    WORKSPACE=${WORKSPACE:-/root/jenkins/workspace/estuary-v500-build}
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

function clean_build() {
    if [ x"$SKIP_BUILD" = x"true" ];then
        :
    else
        sudo rm -fr $BUILD_DIR
    fi
}

function init_input_params() {
    # project name
    TREE_NAME=${TREE_NAME:-"open-estuary"}
    # select a version
    VERSION=${VERSION:-""}
    GIT_DESCRIBE=${GIT_DESCRIBE:-""}


    # preinstall packages
    PACKAGES=${PACKAGES:-""}
    # all setup types
    SETUP_TYPE=${SETUP_TYPE:-""}
}

function parse_params() {
    pushd ${CI_SCRIPTS_DIR}
    : ${SHELL_PLATFORM:=`python configs/parameter_parser.py -f config.yaml -s Build -k Platform`}
    : ${SHELL_DISTRO:=`python configs/parameter_parser.py -f config.yaml -s Build -k Distro`}

    : ${BOOT_PLAN:=`python configs/parameter_parser.py -f config.yaml -s Jenkins -k Boot`}

    : ${TEST_PLAN:=`python configs/parameter_parser.py -f config.yaml -s Test -k Plan`}
    : ${TEST_REPO:=`python configs/parameter_parser.py -f config.yaml -s Test -k Repo`}
    : ${TEST_LEVEL:=`python configs/parameter_parser.py -f config.yaml -s Test -k Level`}

    : ${LAVA_SERVER:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k lavaserver`}
    : ${LAVA_USER:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k lavauser`}
    : ${LAVA_STREAM:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k lavastream`}
    : ${LAVA_TOKEN:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k TOKEN`}

    : ${FTP_SERVER:=`python configs/parameter_parser.py -f config.yaml -s Ftpinfo -k ftpserver`}
    : ${FTP_DIR:=`python configs/parameter_parser.py -f config.yaml -s Ftpinfo -k FTP_DIR`}

    : ${ARCH_MAP:=`python configs/parameter_parser.py -f config.yaml -s Arch`}

    : ${SUCCESS_MAIL_LIST:=`python configs/parameter_parser.py -f config.yaml -s Mail -k SUCCESS_LIST`}
    : ${FAILED_MAIL_LIST:=`python configs/parameter_parser.py -f config.yaml -s Mail -k FAILED_LIST`}

    popd    # restore current work directory
}

function generate_failed_mail(){
    cd ${WORKSPACE}
    echo "${FAILED_MAIL_LIST}" > MAIL_LIST.txt
    echo "Estuary CI Build - ${GIT_DESCRIBE} - Failed" > MAIL_SUBJECT.txt
    cat > MAIL_CONTENT.txt <<EOF
( This mail is send by Jenkins automatically, don't reply )
Project Name: ${TREE_NAME}
Version: ${GIT_DESCRIBE}
Build Status: failed
Build Log Address: ${BUILD_URL}console
Build Project Address: $BUILD_URL
Build and Generated Binaries Address: NONE

The build is failed unexpectly. Please check the log and fix it.

EOF
}


function generate_success_mail(){
    cd ${WORKSPACE}
    if [ "${DEBUG}" = "true" ];then
        echo "${FAILED_MAIL_LIST}" > ${WORKSPACE}/MAIL_LIST.txt
    else
        echo "${SUCCESS_MAIL_LIST}" > ${WORKSPACE}/MAIL_LIST.txt
    fi

    echo "Estuary CI - ${GIT_DESCRIBE} - Result" > ${WORKSPACE}/MAIL_SUBJECT.txt
    cat > ${WORKSPACE}/MAIL_CONTENT.txt <<EOF
( This mail is send by Jenkins automatically, don't reply )
Project Name: ${TREE_NAME}
Version: ${GIT_DESCRIBE}
Build Status: success
Build Log Address: ${BUILD_URL}console
Build Project Address: $BUILD_URL
Build and Generated Binaries Address:${FTP_SERVER}/open-estuary/${GIT_DESCRIBE}
EOF
}

function save_to_properties() {
    cat << EOF > ${WORKSPACE}/env.properties
TREE_NAME="${TREE_NAME}"
GIT_DESCRIBE="${GIT_DESCRIBE}"
SHELL_PLATFORM="${SHELL_PLATFORM}"
SHELL_DISTRO="${SHELL_DISTRO}"
BOOT_PLAN="${BOOT_PLAN}"
TEST_REPO="${TEST_REPO}"
TEST_PLAN="${TEST_PLAN}"
TEST_LEVEL="${TEST_LEVEL}"
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

function sync_code() {
    mkdir -p $OPEN_ESTUARY_DIR;
    pushd $OPEN_ESTUARY_DIR;    # enter OPEN_ESTUARY_DIR

    if [ "$VERSION"x != ""x ]; then
        git clone "https://github.com/open-estuary/estuary.git" -b refs/tags/${VERSION}
    else
        git clone "https://github.com/open-estuary/estuary.git" -b master
    fi

    # TODO : import gpg file
    # wget http://192.168.1.108:8083/v500_build/ESTUARY-GPG-SECURE-KEY
    # gpg --import ESTUARY-GPG-SECURE-KEY
    popd
}

# config the estuarycfg.json , do the build
function do_build() {
    pushd $OPEN_ESTUARY_DIR;    # enter OPEN_ESTUARY_DIR

    # TODO : config cfg files.
    cat $BUILD_CFG_FILE

    # remove all containers
    containers=$(docker ps -a -q)
    if [ -n "${containers}" ];then
        docker rm ${containers}
    fi

    if [ x"$SKIP_BUILD" = x"true" ];then
        echo "skip build"
    else
        # Execute build
        pushd estuary
        ./build.sh --build_dir=${BUILD_DIR}
        if [ $? -ne 0 ]; then
            echo "estuary build failed!"
            exit -1
        fi
        popd
    fi

    print_time "the end time of estuary build is "
    popd
}

# generate version number by git sha
function get_version_info() {
    pushd $OPEN_ESTUARY_DIR;    # enter OPEN_ESTUARY_DIR

    if [ "$VERSION"x != ""x ]; then
        GIT_DESCRIBE=$VERSION
    else

        ESTUARY_GIT_DESCRIBE=$(git log --oneline | head -1 | awk '{print $1}')
        ESTUARY_GIT_DESCRIBE=estuary_${ESTUARY_GIT_DESCRIBE:0:7}
        GIT_DESCRIBE=${ESTUARY_GIT_DESCRIBE}
    fi

    echo $GIT_DESCRIBE
    popd
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

function cp_image() {
    pushd $OPEN_ESTUARY_DIR;    # enter OPEN_ESTUARY_DIR

    DES_DIR=$FTP_DIR/$TREE_NAME/$GIT_DESCRIBE
    [ -d $DES_DIR ] && sudo rm -rf $DES_DIR
    sudo mkdir -p $DES_DIR

    sudo cp $timefile $DES_DIR

    ls -l $BUILD_DIR
    pushd $BUILD_DIR  # enter BUILD_DIR

    cp -r out/release/ ${DES_DIR}/

    popd  # leave BUILD_DIR
    popd  # leave OPEN_ESTUARY_DIR
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

function main() {
    parse_input "$@"
    source_properties_file

    prepare_tools

    init_build_option
    init_workspace
    init_env_params
    init_build_env

    init_input_params
    parse_params

    save_to_properties
    show_properties

    generate_failed_mail

    print_time "the begin time is "

    # if GIT_DESCRIBE have exist, skip build.
    if [ -z "${GIT_DESCRIBE}" ];then
       sync_code
       clean_build

       do_build
       get_version_info
       parse_arch_map
       if [ x"$SKIP_CP_IMAGE" = x"false" ];then
           cp_image
       fi
    else
        DES_DIR=$FTP_DIR/$TREE_NAME/$GIT_DESCRIBE
        if [ -d $DES_DIR ];then
            echo "Skip build, use old build : ${GIT_DESCRIBE}"
        else
            echo "ERROR: wrong ${GIT_DESCRIBE}, don't exist in ftp."
            exit -1
        fi
    fi

    generate_success_mail
    save_to_properties
}

main "$@"
