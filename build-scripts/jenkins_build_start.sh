#!/bin/bash -ex
#: Title                  : jenkins_build_start.sh
#: Usage                  : ./local/ci-scripts/build-scripts/jenkins_build_start.sh -p env.properties
#: Author                 : qinsl0106@thundersoft.com
#: Description            : CI中 编译部分 的jenkins任务脚本，针对v3.1
# the server need open mod loop :
# modprobe loop
# export CODE_REFERENCE=""

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
    WORKSPACE=${WORKSPACE:-/home/ts/jenkins/workspace/estuary-ci}
    mkdir -p ${WORKSPACE}
}

# init sub dirs path
function init_env_params() {
    WORK_DIR=${WORKSPACE}/local
    CI_SCRIPTS_DIR=${WORK_DIR}/ci-scripts
    CODE_REFERENCE=${CODE_REFERENCE:-/estuary_reference}
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
        rm -fr $BUILD_DIR
    fi
}

function init_input_params() {
    # project name
    TREE_NAME=${TREE_NAME:-"open-estuary"}

    # select a version
    VERSION=${VERSION:-""}

    GIT_DESCRIBE=${GIT_DESCRIBE:-""}


    # TODO : no use
    # preinstall packages
    PACKAGES=${PACKAGES:-""}
    # all setup types
    SETUP_TYPE=${SETUP_TYPE:-""}

    JENKINS_JOB_START_TIME=${JENKINS_JOB_START_TIME:-$(current_time)}
}

function parse_params() {
    pushd ${CI_SCRIPTS_DIR}
    : ${SHELL_PLATFORM:=`python configs/parameter_parser.py -f config.yaml -s Build -k Platform`}
    : ${SHELL_DISTRO:=`python configs/parameter_parser.py -f config.yaml -s Build -k Distro`}

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

    : ${ARCH_MAP:=`python configs/parameter_parser.py -f config.yaml -s Arch`}

    : ${SUCCESS_MAIL_LIST:=`python configs/parameter_parser.py -f config.yaml -s Mail -k SUCCESS_LIST`}
    : ${FAILED_MAIL_LIST:=`python configs/parameter_parser.py -f config.yaml -s Mail -k FAILED_LIST`}

    popd    # restore current work directory
}

function generate_failed_mail(){
    cd ${WORKSPACE}
    echo "${FAILED_MAIL_LIST}" > MAIL_LIST.txt
    echo "Estuary CI - ${GIT_DESCRIBE} - Failed" > MAIL_SUBJECT.txt
    cat > MAIL_CONTENT.txt <<EOF
( This mail is send by Jenkins automatically, don't reply )<br>
Project Name: ${TREE_NAME}<br>
Version: ${GIT_DESCRIBE}<br>
Build Status: failed<br>
Boot and Test Status: failed<br>
Build Log Address: ${BUILD_URL}console<br>
Build Project Address: $BUILD_URL<br>
Build and Generated Binaries Address: NONE<br>
The Test Cases Definition Address: ${TEST_REPO}<br>
<br>
The build is failed unexpectly. Please check the log and fix it.<br>
<br>
EOF

}

function save_to_properties() {
    cat << EOF > ${WORKSPACE}/env.properties
TREE_NAME=${TREE_NAME}
GIT_DESCRIBE=${GIT_DESCRIBE}
SHELL_PLATFORM="${SHELL_PLATFORM}"
SHELL_DISTRO="${SHELL_DISTRO}"
BOOT_PLAN="${BOOT_PLAN}"
TEST_REPO=${TEST_REPO}
TEST_PLAN=${TEST_PLAN}
TEST_SCOPE="${TEST_SCOPE}"
TEST_LEVEL=${TEST_LEVEL}
JENKINS_JOB_START_TIME="${JENKINS_JOB_START_TIME}"
ARCH_MAP="${ARCH_MAP}"
EOF
    # EXECUTE_STATUS="Failure"x
    cat ${WORKSPACE}/env.properties
}

function show_properties() {
    cat ${WORKSPACE}/env.properties
}

function prepare_repo_tool() {
    pushd $WORK_DIR
    export PATH=${WORK_DIR}/bin:$PATH;
    if which repo;then
        echo "skip download repo"
    else
        echo "download repo"
        mkdir -p bin;
        wget -c http://download.open-estuary.org/AllDownloads/DownloadsEstuary/utils/repo -O bin/repo
        chmod a+x bin/repo;
    fi
    popd
}

function sync_code() {
    mkdir -p $OPEN_ESTUARY_DIR;

    pushd $OPEN_ESTUARY_DIR;    # enter OPEN_ESTUARY_DIR

    # sync and checkout files from repo
    #repo init
    if [ x"$SKIP_BUILD" = x"true" ];then
        echo "skip git reset and clean"
    else
        repo forall -c git reset --hard || true
        repo forall -c git clean -dxf || true
    fi

    if [ "$VERSION"x != ""x ]; then
        repo init -u "https://github.com/open-estuary/estuary.git" \
             --reference=${CODE_REFERENCE} \
             -b refs/tags/$VERSION --no-repo-verify --repo-url=git://android.git.linaro.org/tools/repo
    else
        repo init -u "https://github.com/open-estuary/estuary.git" \
             --reference=${CODE_REFERENCE} \
             -b master --no-repo-verify --repo-url=git://android.git.linaro.org/tools/repo
    fi

    set +e
    false; while [ $? -ne 0 ]; do repo sync --force-sync; done
    set -e

    repo status

    print_time "time_build_download_estuary_end"
    popd
}

# master don't have arch/arm64/configs/estuary_defconfig file
function hotfix_download_estuary_defconfig() {
    cd $OPEN_ESTUARY_DIR/kernel/arch/arm64/configs
    wget https://raw.githubusercontent.com/open-estuary/kernel/v3.1/arch/arm64/configs/estuary_defconfig -o estuary_defconfig
    cd -
}

# config the estuarycfg.json , do the build
function do_build() {
    pushd $OPEN_ESTUARY_DIR;    # enter OPEN_ESTUARY_DIR

    BUILD_CFG_FILE=/tmp/estuarycfg.json
    cp $ESTUARY_CFG_FILE $BUILD_CFG_FILE

    # Set all platforms support to "no"
    sed -i -e '/platform/s/yes/no/' $BUILD_CFG_FILE

    # Make platforms supported to "yes"
    echo $SHELL_PLATFORM
    for PLATFORM in $SHELL_PLATFORM; do
        PLATFORM_U=${PLATFORM^^}
        sed -i -e "/$PLATFORM_U/s/no/yes/" $BUILD_CFG_FILE
    done

    # Set all distros support to "no"
    distros=(Ubuntu OpenSuse Fedora Debian CentOS Rancher OpenEmbedded)
    for ((i=0; i<${#distros[@]}; i++)); do
        sed -i -e "/${distros[$i]}/s/yes/no/" $BUILD_CFG_FILE
    done

    # Make distros supported to "yes"
    echo $SHELL_DISTRO
    for DISTRO in $SHELL_DISTRO; do
        sed -i -e "/$DISTRO/s/no/yes/" $BUILD_CFG_FILE
    done

    # TODO: disable packages install first. open this when the package is required and ready.
    sed -i -e '/"cmd":/s/install/none/' $BUILD_CFG_FILE

    # Set all packages supported to yes
    echo $PACKAGES
    for package in $PACKAGES; do
        sed -i -e "/${package}/s/no/yes/" $BUILD_CFG_FILE
    done

    # Set all setup types supported to "no"
    echo $SETUP_TYPE
    for setuptype in $SETUP_TYPE;do
        sed -i -e "/${setuptype}/s/yes/no/" $BUILD_CFG_FILE
    done

    cat $BUILD_CFG_FILE

    if [ x"$SKIP_BUILD" = x"true" ];then
        echo "skip build"
    else
        # Execute build
        ./estuary/build.sh --file=$BUILD_CFG_FILE --builddir=$BUILD_DIR
        if [ $? -ne 0 ]; then
            echo "estuary build failed!"
            exit -1
        fi
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
        #### get uefi commit
        pushd uefi
        UEFI_GIT_DESCRIBE=$(git log --oneline | head -1 | awk '{print $1}')
        UEFI_GIT_DESCRIBE=uefi_${UEFI_GIT_DESCRIBE:0:7}
        popd

        #### get kernel commit
        pushd kernel
        KERNEL_GIT_DESCRIBE=$(git log --oneline | head -1 | awk '{print $1}')
        KERNEL_GIT_DESCRIBE=kernel_${KERNEL_GIT_DESCRIBE:0:7}
        popd

        #### get grub commit
        pushd grub
        GURB_GIT_DESCRIBE=$(git log --oneline | head -1 | awk '{print $1}')
        GURB_GIT_DESCRIBE=grub_${GURB_GIT_DESCRIBE:0:7}
        popd

        GIT_DESCRIBE=${UEFI_GIT_DESCRIBE}_${GURB_GIT_DESCRIBE}_${KERNEL_GIT_DESCRIBE}
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

# image dir tree:
# .
# `-- kernel-ci
#     `-- open-estuary
#         `-- uefi_b386a15_grub_daac831_kernel_6eade8c
#             |-- arm64
#             |   |-- Estuary.iso
#             |   |-- Image
#             |   |-- System.map
#             |   |-- Ubuntu_ARM64.tar.gz
#             |   |-- Ubuntu_ARM64.tar.gz.sum
#             |   |-- deploy-utils.tar.bz2
#             |   |-- gcc-linaro-aarch64-linux-gnu-4.9-2014.09_linux.tar.xz
#             |   |-- gcc-linaro-arm-linux-gnueabihf-4.9-2014.09_linux.tar.xz
#             |   |-- grubaa64.efi
#             |   |-- mini-rootfs.cpio.gz
#             |   `-- vmlinux
#             |-- d05-arm64
#             |   |-- binary
#             |   |   |-- Image_D05 -> ../../arm64/Image
#             |   |   |-- UEFI_D05.fd
#             |   |   |-- deploy-utils.tar.bz2 -> ../../arm64/deploy-utils.tar.bz2
#             |   |   |-- grub.cfg
#             |   |   |-- grubaa64.efi -> ../../arm64/grubaa64.efi
#             |   |   `-- mini-rootfs.cpio.gz -> ../../arm64/mini-rootfs.cpio.gz
#             |   |-- distro
#             |   |   |-- Ubuntu_ARM64.tar.gz -> ../../arm64/Ubuntu_ARM64.tar.gz
#             |   |   `-- Ubuntu_ARM64.tar.gz.sum -> ../../arm64/Ubuntu_ARM64.tar.gz.sum
#             |   `-- toolchain
#             |       `-- gcc-linaro-aarch64-linux-gnu-4.9-2014.09_linux.tar.xz -> ../../arm64/gcc-linaro-aarch64-linux-gnu-4.9-2014.09_linux.tar.xz
#             `-- timestamp.properties
function cp_image() {
    pushd $OPEN_ESTUARY_DIR;    # enter OPEN_ESTUARY_DIR

    DEPLOY_UTILS_FILE=deploy-utils.tar.bz2
    MINI_ROOTFS_FILE=mini-rootfs.cpio.gz
    GRUB_IMG_FILE=grubaa64.efi
    GRUB_CFG_FILE=grub.cfg
    KERNEL_IMG_FILE=Image
    TOOLCHAIN_FILE=gcc-linaro-aarch64-linux-gnu-4.9-2014.09_linux.tar.xz

    DES_DIR=$FTP_DIR/$TREE_NAME/$GIT_DESCRIBE
    [ -d $DES_DIR ] && rm -rf $DES_DIR
    mkdir -p $DES_DIR

    cp $timefile $DES_DIR

    ls -l $BUILD_DIR
    pushd $BUILD_DIR  # enter BUILD_DIR

    # copy arch files
    pushd binary
    for arch_dir in arm*;do
        mkdir -p $DES_DIR/$arch_dir
        cp $arch_dir/* $DES_DIR/$arch_dir
    done
    popd

    # copy platfom files
    for PLATFORM in $SHELL_PLATFORM; do
        echo $PLATFORM

        PLATFORM_L="$(echo $PLATFORM | tr '[:upper:]' '[:lower:]')"
        PLATFORM_U="$(echo $PLATFORM | tr '[:lower:]' '[:upper:]')"
        PLATFORM_ARCH_DIR=$DES_DIR/${PLATFORM_L}-${arch[$PLATFORM_L]}
        [ -d $PLATFORM_ARCH_DIR ] && rm -fr $PLATFORM_ARCH_DIR
        mkdir -p ${PLATFORM_ARCH_DIR}/{binary,toolchain,distro}

        # copy toolchain files
        pushd $PLATFORM_ARCH_DIR/toolchain
        ln -s ../../${arch[$PLATFORM_L]}/$TOOLCHAIN_FILE
        popd

        # copy binary files
        find binary/$PLATFORM_U/ -type l -exec rm {} \;  || true # ensure remove symlinks
        cp -rf binary/$PLATFORM_U/* $PLATFORM_ARCH_DIR/binary

        pushd $PLATFORM_ARCH_DIR/binary
        ln -s ../../${arch[$PLATFORM_L]}/$KERNEL_IMG_FILE ${KERNEL_IMG_FILE}_${PLATFORM_U}
        ln -s ../../${arch[$PLATFORM_L]}/$DEPLOY_UTILS_FILE
        ln -s ../../${arch[$PLATFORM_L]}/$MINI_ROOTFS_FILE
        ln -s ../../${arch[$PLATFORM_L]}/$GRUB_IMG_FILE

        # TODO : ln: failed to create symbolic link './grub.cfg': File exists
        ln -s ../../${arch[$PLATFORM_L]}/$GRUB_CFG_FILE || true
        popd

        # copy distro files
        for DISTRO in $SHELL_DISTRO;do
            echo $DISTRO

            pushd ${CI_SCRIPTS_DIR}
            distro_tar_name=`python configs/parameter_parser.py -f config.yaml -s DISTRO -k $PLATFORM_U -v $DISTRO`
            popd

            if [ x"$distro_tar_name" = x"" ]; then
                continue
            fi

            echo $distro_tar_name

            pushd $DES_DIR/${arch[$PLATFORM_L]}
            [ ! -f ${distro_tar_name}.sum ] && sh -c "md5sum $distro_tar_name > ${distro_tar_name}.sum"
            popd

            pushd $PLATFORM_ARCH_DIR/distro
            ln -s ../../${arch[$PLATFORM_L]}/$distro_tar_name
            ln -s ../../${arch[$PLATFORM_L]}/$distro_tar_name.sum
            popd
        done
    done

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
    set_timezone_china

    parse_input "$@"
    source_properties_file

    init_timefile build

    prepare_tools "python-yaml"
    ensure_services_start "docker"

    init_build_option
    init_workspace
    init_env_params
    init_build_env

    init_input_params
    parse_params

    save_to_properties
    show_properties

    generate_failed_mail

    print_time "time_build_build_begin"
    prepare_repo_tool

    # if GIT_DESCRIBE have exist, skip build.
    if [ -z "${GIT_DESCRIBE}" ];then
       sync_code
       clean_build

       # hotfix_download_estuary_defconfig
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

    save_to_properties
}

main "$@"
