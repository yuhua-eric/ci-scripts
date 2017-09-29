#!/bin/bash -ex

# prepare system tools
function prepare_tools() {
    dev_tools="sshpass"

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
    SHELL_PLATFORM=${SHELL_PLATFORM:-"d05"}
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

function prepare_repo_tool() {
    pushd $WORK_DIR
    mkdir -p bin;
    export PATH=${WORK_DIR}/bin:$PATH;
    if [ ! -e bin ]; then
        if which repo;then
            echo "skip download repo"
        else
            echo "download repo"
            wget -c http://download.open-estuary.org/AllDownloads/DownloadsEstuary/utils/repo -O bin/repo
            chmod a+x bin/repo;
        fi
    fi
    popd
}

# master don't have arch/arm64/configs/estuary_defconfig file
function hotfix_download_estuary_defconfig() {
    cd $OPEN_ESTUARY_DIR/kernel/arch/arm64/configs
    wget https://raw.githubusercontent.com/open-estuary/kernel/v3.1/arch/arm64/configs/estuary_defconfig -o estuary_defconfig
    cd -
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
#             `-- timestamp.log
function cp_image() {
    pushd $OPEN_ESTUARY_DIR;    # enter OPEN_ESTUARY_DIR

    DEPLOY_UTILS_FILE=deploy-utils.tar.bz2
    MINI_ROOTFS_FILE=mini-rootfs.cpio.gz
    GRUB_IMG_FILE=grubaa64.efi
    GRUB_CFG_FILE=grub.cfg
    KERNEL_IMG_FILE=Image
    TOOLCHAIN_FILE=gcc-linaro-aarch64-linux-gnu-4.9-2014.09_linux.tar.xz

    DES_DIR=$FTP_DIR/$TREE_NAME/$GIT_DESCRIBE
    [ -d $DES_DIR ] && sudo rm -rf $DES_DIR
    sudo mkdir -p $DES_DIR

    sudo cp $timefile $DES_DIR

    ls -l $BUILD_DIR
    pushd $BUILD_DIR  # enter BUILD_DIR

    # copy arch files
    pushd binary
    for arch_dir in arm*;do
        sudo mkdir -p $DES_DIR/$arch_dir
        sudo cp $arch_dir/* $DES_DIR/$arch_dir
    done
    popd

    # copy platfom files
    for PLATFORM in $SHELL_PLATFORM; do
        echo $PLATFORM

        PLATFORM_L="$(echo $PLATFORM | tr '[:upper:]' '[:lower:]')"
        PLATFORM_U="$(echo $PLATFORM | tr '[:lower:]' '[:upper:]')"
        PLATFORM_ARCH_DIR=$DES_DIR/${PLATFORM_L}-${arch[$PLATFORM_L]}
        [ -d $PLATFORM_ARCH_DIR ] && sudo rm -fr $PLATFORM_ARCH_DIR
        sudo mkdir -p ${PLATFORM_ARCH_DIR}/{binary,toolchain,distro}

        # copy toolchain files
        pushd $PLATFORM_ARCH_DIR/toolchain
        sudo ln -s ../../${arch[$PLATFORM_L]}/$TOOLCHAIN_FILE
        popd

        # copy binary files
        sudo find binary/$PLATFORM_U/ -type l -exec rm {} \;  || true # ensure remove symlinks
        sudo cp -rf binary/$PLATFORM_U/* $PLATFORM_ARCH_DIR/binary

        pushd $PLATFORM_ARCH_DIR/binary
        sudo ln -s ../../${arch[$PLATFORM_L]}/$KERNEL_IMG_FILE ${KERNEL_IMG_FILE}_${PLATFORM_U}
        sudo ln -s ../../${arch[$PLATFORM_L]}/$DEPLOY_UTILS_FILE
        sudo ln -s ../../${arch[$PLATFORM_L]}/$MINI_ROOTFS_FILE
        sudo ln -s ../../${arch[$PLATFORM_L]}/$GRUB_IMG_FILE

        # TODO : ln: failed to create symbolic link './grub.cfg': File exists
        sudo ln -s ../../${arch[$PLATFORM_L]}/$GRUB_CFG_FILE || true
        popd

        # copy distro files
        for DISTRO in $SHELL_DISTRO;do
            echo $DISTRO

            pushd ${CI_SCRIPTS_DIR}
            distro_tar_name=`python parameter_parser.py -f config.yaml -s DISTRO -k $PLATFORM_U -v $DISTRO`
            popd

            if [ x"$distro_tar_name" = x"" ]; then
                continue
            fi

            echo $distro_tar_name

            pushd $DES_DIR/${arch[$PLATFORM_L]}
            [ ! -f ${distro_tar_name}.sum ] && sudo sh -c "md5sum $distro_tar_name > ${distro_tar_name}.sum"
            popd

            pushd $PLATFORM_ARCH_DIR/distro
            sudo ln -s ../../${arch[$PLATFORM_L]}/$distro_tar_name
            sudo ln -s ../../${arch[$PLATFORM_L]}/$distro_tar_name.sum
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

function do_deploy() {
    # do deploy
    :
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
    prepare_repo_tool

    parse_arch_map

    do_deploy

    save_to_properties
}

main "$@"
