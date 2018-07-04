#!/bin/bash -ex
#: Title                  : jenkins_build_v500_start.sh
#: Usage                  : ./local/ci-scripts/build-scripts/jenkins_build_v500_start.sh -p env.properties
#: Author                 : qinsl0106@thundersoft.com
#: Description            : CI中自动编译的jenkins任务脚本，针对v500
# only works on centos

__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
source "${script_path}/../common-scripts/common.sh"

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

    # TODO : workaround for v500 build
    OPEN_ESTUARY_DIR=${WORK_DIR}/open-estuary
    # OPEN_ESTUARY_DIR=/root

    BUILD_DIR=${OPEN_ESTUARY_DIR}/estuary/build
    ESTUARY_CFG_FILE=${OPEN_ESTUARY_DIR}/estuary/estuarycfg.json
}

function clean_build() {
    if [ x"$SKIP_BUILD" = x"true" ];then
        :
    else
        rm -fr $BUILD_DIR
    fi
}

function init_input_params() {
    # project name
    TREE_NAME=${TREE_NAME:-"open-estuary"}
    # select a version
    SOURCE_CODE=${SOURCE_CODE:-"https://github.com/open-estuary/estuary.git"}
    BRANCH=${BRANCH:-""}
    VERSION=${VERSION:-""}
    GIT_DESCRIBE=${GIT_DESCRIBE:-""}


    # preinstall packages
    PACKAGES=${PACKAGES:-""}
    # all setup types
    SETUP_TYPE=${SETUP_TYPE:-""}

    DEBUG=${DEBUG:-""}

    JENKINS_JOB_START_TIME=${JENKINS_JOB_START_TIME:-$(current_time)}
}

function parse_params() {
    pushd ${CI_SCRIPTS_DIR}
    : ${SHELL_PLATFORM:=`python configs/parameter_parser.py -f config.yaml -s Build -k Platform`}
    : ${ALL_SHELL_PLATFORM:=`python configs/parameter_parser.py -f config.yaml -s Build -k Platform`}
    : ${SHELL_DISTRO:=`python configs/parameter_parser.py -f config.yaml -s Build -k Distro`}
    : ${ALL_SHELL_DISTRO:=`python configs/parameter_parser.py -f config.yaml -s Build -k Distro`}

    : ${BOOT_PLAN:=`python configs/parameter_parser.py -f config.yaml -s Jenkins -k Boot`}

    : ${TEST_PLAN:=`python configs/parameter_parser.py -f config.yaml -s Test -k Plan`}
    : ${TEST_SCOPE:=`python configs/parameter_parser.py -f config.yaml -s Test -k Scope`}
    : ${TEST_REPO:=`python configs/parameter_parser.py -f config.yaml -s Test -k Repo`}
    : ${TEST_LEVEL:=`python configs/parameter_parser.py -f config.yaml -s Test -k Level`}

    : ${LAVA_SERVER:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k lavaserver`}
    : ${LAVA_USER:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k lavauser`}
    : ${LAVA_STREAM:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k lavastream`}
    : ${LAVA_TOKEN:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k TOKEN`}

    : ${FTP_SERVER:=`python configs/parameter_parser.py -f config.yaml -s Ftpinfo -k ftpserver`}
    : ${FTP_DIR:=`python configs/parameter_parser.py -f config.yaml -s Ftpinfo -k FTP_DIR`}
    : ${STASH_DIR:=`python configs/parameter_parser.py -f config.yaml -s Ftpinfo -k STASH_DIR`}
    : ${FTPSERVER_DISPLAY_URL:=`python configs/parameter_parser.py -f config.yaml -s Ftpinfo -k FTPSERVER_DISPLAY_URL`}

    : ${ARCH_MAP:=`python configs/parameter_parser.py -f config.yaml -s Arch`}

    : ${SUCCESS_MAIL_LIST:=`python configs/parameter_parser.py -f config.yaml -s Mail -k SUCCESS_LIST`}
    : ${SUCCESS_MAIL_CC_LIST:=`python configs/parameter_parser.py -f config.yaml -s Mail -k SUCCESS_CC_LIST`}
    : ${FAILED_MAIL_LIST:=`python configs/parameter_parser.py -f config.yaml -s Mail -k FAILED_LIST`}
    : ${FAILED_MAIL_CC_LIST:=`python configs/parameter_parser.py -f config.yaml -s Mail -k FAILED_CC_LIST`}

    popd    # restore current work directory
}

function generate_failed_mail(){
    cd ${WORKSPACE}
    echo "${FAILED_MAIL_LIST}" > MAIL_LIST.txt
    echo "${FAILED_MAIL_CC_LIST}" > MAIL_CC_LIST.txt
    echo "Estuary CI Build - ${GIT_DESCRIBE} - Failed" > MAIL_SUBJECT.txt
    cat > MAIL_CONTENT.txt <<EOF
( This mail is send by Jenkins automatically, don't reply )<br>
Project Name: ${TREE_NAME}<br>
Version: ${GIT_DESCRIBE}<br>
Build Status: failed<br>
Build Log Address: ${BUILD_URL}console<br>
Build Project Address: $BUILD_URL<br>
Build and Generated Binaries Address: NONE<br>
<br>
The build is failed unexpectly. Please check the log and fix it.<br>
<br>
EOF
}


function generate_success_mail(){
    cd ${WORKSPACE}
    echo "${SUCCESS_MAIL_LIST}" > ${WORKSPACE}/MAIL_LIST.txt
    echo "${SUCCESS_MAIL_CC_LIST}" > ${WORKSPACE}/MAIL_CC_LIST.txt

    echo "Estuary CI - ${GIT_DESCRIBE} - Result" > ${WORKSPACE}/MAIL_SUBJECT.txt
    cat > ${WORKSPACE}/MAIL_CONTENT.txt <<EOF
( This mail is send by Jenkins automatically, don't reply )<br>
Project Name: ${TREE_NAME}<br>
Version: ${GIT_DESCRIBE}<br>
Build Status: success<br>
Build Log Address: ${BUILD_URL}console<br>
Build Project Address: $BUILD_URL<br>
Build and Generated Binaries Address:${FTPSERVER_DISPLAY_URL}/open-estuary/${GIT_DESCRIBE}<br>
EOF
}

function save_properties_and_result() {
    local build_result=$1

    cat << EOF > ${WORKSPACE}/env.properties
TREE_NAME=${TREE_NAME}
GIT_DESCRIBE=${GIT_DESCRIBE}
SHELL_PLATFORM="${SHELL_PLATFORM}"
SHELL_DISTRO="${SHELL_DISTRO}"
BOOT_PLAN=${BOOT_PLAN}
TEST_REPO=${TEST_REPO}
TEST_PLAN=${TEST_PLAN}
TEST_SCOPE="${TEST_SCOPE}"
TEST_LEVEL=${TEST_LEVEL}
DEBUG=${DEBUG}
JENKINS_JOB_START_TIME="${JENKINS_JOB_START_TIME}"
ARCH_MAP="${ARCH_MAP}"
EOF
    # EXECUTE_STATUS="Failure"x
    cat ${WORKSPACE}/env.properties

    echo "${build_result}" > ${WORKSPACE}/build_result.txt
}

function show_properties() {
    cat ${WORKSPACE}/env.properties
}

function sync_code() {
    mkdir -p $OPEN_ESTUARY_DIR;
    pushd $OPEN_ESTUARY_DIR;    # enter OPEN_ESTUARY_DIR

    # remove old estuary repo
    rm -rf estuary
	git clone ${SOURCE_CODE}
	
    #if [ "$VERSION"x != ""x ]; then
    #    if [ -d "estuary" ];then
    #        cd estuary
    #        git fetch
    #        git checkout refs/tags/${VERSION}
    #        cd -
    #    else
    #        git clone "https://github.com/open-estuary/estuary.git"
    #        cd estuary
    #        git checkout refs/tags/${VERSION}
    #        cd -
    #    fi
    #else
    #    if [ -d "estuary" ];then
    #        cd estuary
    #        git fetch
    #        git checkout origin/master
    #        cd -
    #    else
    #        git clone "https://github.com/open-estuary/estuary.git" -b master
    #    fi
    #fi
	if [ "$BRANCH"x != ""x ]; then
        cd estuary
        git checkout ${BRANCH}
        cd -
    fi
	
	if [ "$VERSION"x != ""x ]; then
        cd estuary
        git checkout refs/tags/${VERSION}
        cd -
    fi

    # TODO : import gpg file
    # wget http://192.168.1.108:8083/v500_build/ESTUARY-GPG-SECURE-KEY
    # gpg --import ESTUARY-GPG-SECURE-KEY
    popd
}

# config the estuarycfg.json , do the build
function do_build() {
    pushd $OPEN_ESTUARY_DIR;    # enter OPEN_ESTUARY_DIR

    # remove all containers
    containers=$(docker ps -a -q)
    if [ -n "${containers}" ];then
        docker rm -f ${containers}
    fi

    if [ x"$SKIP_BUILD" = x"true" ];then
        echo "skip build"
    else
        # Execute build
        pushd estuary
        # TODO : workaround for build all in single machine
        for DISTRO in $ALL_SHELL_DISTRO;do
            ./build.sh --build_dir=${BUILD_DIR} -d "${DISTRO,,}" &
            sleep 1m
        done
        ./build.sh --build_dir=${BUILD_DIR} -d common &
        wait

        # ./build.sh --build_dir=${BUILD_DIR}
        popd
    fi

    print_time "time_build_build_end"
    popd
}

# generate version number by git sha
function get_version_info() {
    pushd $OPEN_ESTUARY_DIR;    # enter OPEN_ESTUARY_DIR

    if [ "$VERSION"x != ""x ]; then
        GIT_DESCRIBE=$VERSION
    else
        cd estuary
        ESTUARY_GIT_DESCRIBE=$(git log --oneline | head -1 | awk '{print $1}')
        # cd kernel
        # KERNEL_GIT_DESCRIBE=$(git log --oneline | head -1 | awk '{print $1}')
        cd -
        GIT_DESCRIBE=daily_$(current_day)
        cd -

        echo "ESTUARY_GIT_DESCRIBE=${ESTUARY_GIT_DESCRIBE}" > ${WORKSPACE}/version.properties
        # echo "KERNEL_GIT_DESCRIBE=${KERNEL_GIT_DESCRIBE}" >> ${WORKSPACE}/version.properties
    fi

    popd
    echo $GIT_DESCRIBE
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

    DES_DIR=$STASH_DIR/$TREE_NAME/$GIT_DESCRIBE

    # do clean
    rm -rf $STASH_DIR/$TREE_NAME/
    [ -d $DES_DIR ] && rm -rf $DES_DIR

    mkdir -p $DES_DIR

    cp $timefile $DES_DIR

    ls -l $BUILD_DIR
    pushd $BUILD_DIR  # enter BUILD_DIR

    cp -r out/release/*/* ${DES_DIR}/

    pushd ${DES_DIR} # enter DES_DIR
    MINI_ROOTFS_FILE=mini-rootfs.cpio.gz
    GRUB_IMG_FILE=grubaa64.efi
    GRUB_CFG_FILE=grub.cfg
    KERNEL_IMG_FILE=Image

    # copy platfom files
    # TODO : workaround to prepare all platform image
    # for PLATFORM in $SHELL_PLATFORM; do
    for PLATFORM in $ALL_SHELL_PLATFORM; do
        echo $PLATFORM

        PLATFORM_L="$(echo $PLATFORM | tr '[:upper:]' '[:lower:]')"
        PLATFORM_U="$(echo $PLATFORM | tr '[:lower:]' '[:upper:]')"
        PLATFORM_ARCH_DIR=$DES_DIR/${PLATFORM_L}-${arch[$PLATFORM_L]}
        [ -d $PLATFORM_ARCH_DIR ] && rm -fr $PLATFORM_ARCH_DIR
        mkdir -p ${PLATFORM_ARCH_DIR}/{binary,distro}

        pushd $PLATFORM_ARCH_DIR/binary
        ln -s ../../binary/${arch[$PLATFORM_L]}/$KERNEL_IMG_FILE ${KERNEL_IMG_FILE}_${PLATFORM_U}
        ln -s ../../binary/${arch[$PLATFORM_L]}/$MINI_ROOTFS_FILE
        ln -s ../../binary/${arch[$PLATFORM_L]}/$GRUB_IMG_FILE

        popd

        # copy distro files
        for DISTRO in $ALL_SHELL_DISTRO;do
            echo $DISTRO

            pushd ${CI_SCRIPTS_DIR}
            distro_tar_name=`python configs/parameter_parser.py -f config.yaml -s DISTRO -k $PLATFORM_U -v $DISTRO`
            popd

            if [ x"$distro_tar_name" = x"" ]; then
                continue
            fi

            echo $distro_tar_name

            pushd $DES_DIR/binary/${arch[$PLATFORM_L]}
            [ ! -f ${distro_tar_name,,}.sum ] && md5sum ${distro_tar_name,,} > ${distro_tar_name,,}.sum
            popd

            pushd $PLATFORM_ARCH_DIR/distro
            ln -s ../../binary/${arch[$PLATFORM_L]}/${distro_tar_name,,} $distro_tar_name
            ln -s ../../binary/${arch[$PLATFORM_L]}/${distro_tar_name,,}.sum $distro_tar_name.sum
            popd
        done
    done

    popd  # leave DES_DIR
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
            p)  PROPERTIES_FILE=$OPTARG
                ;;
        esac
    done

    shift $((OPTIND-1))

    [ "$1" = "--" ] && shift

    echo "properties_file='$properties_file', Leftovers: $@"
}

function main() {
    set_timezone_china

    parse_input "$@"
    source_properties_file "${PROPERTIES_FILE}"

    init_timefile build

    prepare_tools "python-yaml"
    ensure_services_start "docker"

    init_build_option
    init_workspace
    init_env_params
    init_build_env

    init_input_params
    parse_params

    save_properties_and_result fail
    show_properties

    generate_failed_mail

    print_time "time_build_build_begin"

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
        DES_DIR=$STASH_DIR/$TREE_NAME/$GIT_DESCRIBE
        if [ -d $DES_DIR ];then
            echo "Skip build, use old build : ${GIT_DESCRIBE}"
        else
            echo "ERROR: wrong ${GIT_DESCRIBE}, don't exist in ftp."
            exit -1
        fi
    fi
    save_properties_and_result pass

    generate_success_mail
}

main "$@"
