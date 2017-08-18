#!/bin/bash -ex
function init_build_option() {
    SKIP_LAVA_RUN=${SKIP_LAVA_RUN:-"false"}
}

function init_workspace() {
    WORKSPACE=${WORKSPACE:-/home/ts/jenkins/workspace/estuary-build}
    mkdir -p ${WORKSPACE}
}

function init_input_params() {
    TREE_NAME=${TREE_NAME:-"open-estuary"}

    VERSION=${VERSION:-""}

    GIT_DESCRIBE=${GIT_DESCRIBE:-"uefi_b386a15_grub_daac831_kernel_6eade8c"}

    SHELL_PLATFORM=${SHELL_PLATFORM:-"d05"}
    SHELL_DISTRO=${SHELL_DISTRO:-"Ubuntu"}
    ARCH_MAP=${ARCH_MAP:-"d05 arm64"}

    BOOT_PLAN=${BOOT_PLAN:-"BOOT_NFS BOOT_SAS"}
    APP_PLAN=${APP_PLAN:-"TEST"}
}

function parse_params() {
    pushd ${CI_SCRIPTS_DIR}/boot-app-scripts    # change current work directory
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

function prepare_tools() {
    dev_tools="python-yaml python-keyring expect"

    if ! (dpkg-query -l $dev_tools >/dev/null 2>&1); then
        sudo apt-get update
        if ! (sudo apt-get install -y --force-yes $dev_tools); then
            echo "ERROR: can't install tools: ${dev_tools}"
            exit 1
        fi
    fi
}

function init_boot_env() {
    JOBS_DIR=jobs
    RESULTS_DIR=results
}

function generate_jobs() {
    test_name=$1
    distro=$2
    harddisk_flag=$3
    pwd
    for PLAT in $SHELL_PLATFORM; do
        board_arch=${dict[$PLAT]}
        if [ x"$distro" != x"" ]; then
            python estuary-ci-job-creator.py $FTP_SERVER/${TREE_NAME}/${GIT_DESCRIBE}/${PLAT}-${board_arch}/ --plans $test_name --distro $distro $harddisk_flag --arch ${board_arch}
        else
            python estuary-ci-job-creator.py $FTP_SERVER/${TREE_NAME}/${GIT_DESCRIBE}/${PLAT}-${board_arch}/ --plans $test_name --arch ${board_arch}
        fi
    done
}

function run_and_report_jobs() {
    if [ x"$SKIP_LAVA_RUN" = x"false" ];then
        pushd ${JOBS_DIR}
        python ../estuary-job-runner.py --username $LAVA_USER --token $LAVA_TOKEN --server $LAVA_SERVER --stream $LAVA_STREAM --poll POLL
        popd

        if [ ! -f ${JOBS_DIR}/${RESULTS_DIR}/POLL ]; then
            echo "Running jobs error! Aborting"
            return -1
        fi

        python estuary-report.py --boot ${JOBS_DIR}/${RESULTS_DIR}/POLL --lab $LAVA_USER
        if [ ! -d ${RESULTS_DIR} ]; then
            echo "running jobs error! Aborting"
            return -1
        fi
    else
        echo "skip lava run and report"
    fi
}

function judge_pass_or_not() {
    FAIL_FLAG=$(grep -R 'FAIL' ./${JOBS_DIR}/${RESULTS_DIR}/POLL || true)
    if [ "$FAIL_FLAG"x != ""x ]; then
        echo "jobs fail"
        return -1
    fi

    PASS_FLAG=$(grep -R 'PASS' ./${JOBS_DIR}/${RESULTS_DIR}/POLL || true)
    if [ "$PASS_FLAG"x = ""x ]; then
        echo "jobs fail"
        return -1
    fi
    return 0
}

function run_and_move_result() {
    test_name=$1
    dest_dir=$2
    ret_val=0

    if ! run_and_report_jobs ;then
        ret_val=-1
    fi

    if ! judge_pass_or_not ; then
        ret_val=-1
    fi

    [ ! -d ${dest_dir} ] && mkdir -p ${dest_dir}
    [ -d ${JOBS_DIR} ] && mv ${JOBS_DIR} ${dest_dir}/${JOBS_DIR}_${test_name}
    [ -d ${RESULTS_DIR} ] && mv ${RESULTS_DIR} ${dest_dir}/${RESULTS_DIR}_${test_name}

    if [ "$ret_val" -ne 0 ]; then
        return -1
    else
        return 0
    fi
}

function print_time() {
    echo -e "@@@@@@"$@ `date "+%Y-%m-%d %H:%M:%S"` "\n" >> $timefile
    #echo -e "\n"  >> $timefile
}

export

#######  Begining the tests ######

function init_timefile() {
    timefile=${WORKSPACE}/timestamp_boot.txt
    if [ -f ${timefile} ]; then
        rm -fr ${timefile}
    else
        touch ${timefile}
    fi
}

function init_summaryfile() {
    if [ -f ${WORKSPACE}/whole_summary.txt ]; then
        rm -rf ${WORKSPACE}/whole_summary.txt
    else
        touch ${WORKSPACE}/whole_summary.txt
    fi
}

function parse_arch_map() {
    read -a arch <<< $(echo $ARCH_MAP)
    declare -A -g dict
    for((i=0; i<${#arch[@]}; i++)); do
        if ((i%2==0)); then
            j=`expr $i+1`
            dict[${arch[$i]}]=${arch[$j]}
        fi
    done

    for key in "${!dict[@]}"; do echo "$key - ${dict[$key]}"; done
}

function clean_workspace() {
    ##### remove all file from the workspace #####
    rm -rf ${CI_SCRIPTS_DIR}/uef* test_result.tar.gz||true
    rm -rf ${WORKSPACE}/*.txt||true
}

function trigger_lava_build() {
    pushd ${WORKSPACE}/local/ci-scripts/boot-app-scripts
    mkdir -p ${GIT_DESCRIBE}/${RESULTS_DIR}
    for DISTRO in $SHELL_DISTRO; do
        if [ -d $DISTRO ];then
            rm -fr $DISTRO
        fi

        for boot_plan in $BOOT_PLAN; do
            rm -fr ${JOBS_DIR} ${RESULTS_DIR}

            # generate the boot jobs for all the targets
            if [ "$boot_plan" = "BOOT_SAS" ] || [ "$boot_plan" = "BOOT_SATA" ]; then
                # TODO : need rewrite the logic by lava2 way to boot from STAT or SAS.
                # now ti generate to flag boot and sas by the job generate.
                generate_jobs "boot" $DISTRO
                [ $? -ne 0 ] && continue

                # create the boot jobs for each target and run all these jobs
                cd ${JOBS_DIR}
                ls
                if ! python ../create_boot_job.py --username $LAVA_USER --token $LAVA_TOKEN --server $LAVA_SERVER --stream $LAVA_STREAM; then
                    echo "generate the jobs according the board devices error! Aborting"
                    continue
                fi

                cd ..

                if ! run_and_move_result "boot" $DISTRO ;then
                    python parser.py -d $DISTRO
                    if [ ! -d ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO} ];then
                        mv ${DISTRO} ${GIT_DESCRIBE}/${RESULTS_DIR}/ && continue
                    else
                        cp -fr ${DISTRO}/* ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO}/ && continue
                    fi
                fi

                print_time "the end time of deploy $DISTRO in HD through PXE is "

                #########################################
                ##### Entering the sata disk rootfs #####
                # generate the boot jobs for one target
                BOOT_FOR_TEST=BOOT_SAS
                rm -fr ${JOBS_DIR} ${RESULTS_DIR}

                generate_jobs ${BOOT_FOR_TEST} $DISTRO "--SasFlag"
                [ $? -ne 0 ] && continue

                cd ${JOBS_DIR}
                if ! python ../create_boot_job.py --username $LAVA_USER --token $LAVA_TOKEN --server $LAVA_SERVER --stream $LAVA_STREAM; then
                    echo "generate the jobs according the board devices error! Aborting"
                    continue
                fi

                cd ..
                if [ -d ${JOBS_DIR} ]; then
                    if ! run_and_move_result ${BOOT_FOR_TEST} $DISTRO ;then
                        python parser.py -d $DISTRO
                        if [ ! -d ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO} ];then
                            mv ${DISTRO} ${GIT_DESCRIBE}/${RESULTS_DIR} && continue
                        else
                            cp -fr ${DISTRO}/* ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO}/ && continue
                        fi
                    fi
                fi

                print_time "the end time of boot $DISTRO from HD is "
                ##### End of entering the sata disk #####

                if [ x"$APP_PLAN" != x ] ; then
                    #####  modify the ip address according to the boot information
                    DEVICE_IP='device_ip_type.txt'
                    rm -fr /etc/lava-dispatcher/devices/$DEVICE_IP
                    cat $DISTRO/${RESULTS_DIR}_${BOOT_FOR_TEST}/${LAVA_USER}/${DEVICE_IP}
                    cp $DISTRO/${RESULTS_DIR}_${BOOT_FOR_TEST}/${LAVA_USER}/${DEVICE_IP} /etc/lava-dispatcher/devices
                    cp modify_conf_file.sh /etc/lava-dispatcher/devices
                    cd /etc/lava-dispatcher/devices; ./modify_conf_file.sh; cd -
                    sudo rm -fr $HOME/.ssh/known_hosts

                    if [ $? -ne 0 ]; then
                        echo "create ip and host mapping error! Aborting"
                        python parser.py  -d $DISTRO
                        if [ ! -d ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO} ];then
                            mv ${DISTRO} ${GIT_DESCRIBE}/${RESULTS_DIR} && continue
                        else
                            cp -fr ${DISTRO}/* ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO}/ && continue
                        fi
                    fi

                    rm -fr ${JOBS_DIR} ${RESULTS_DIR}
                    # generate the application jobs for the board_types
                    for app_plan in $APP_PLAN; do
                        [[ $app_plan =~ "BOOT" ]] && continue
                        if ! generate_jobs $app_plan $DISTRO ;then
                            python parser.py -d $DISTRO
                            if [ ! -d ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO} ];then
                                mv ${DISTRO} ${GIT_DESCRIBE}/${RESULTS_DIR}/ && continue
                            else
                                cp -fr ${DISTRO}/* ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO}/ && continue
                            fi
                        fi
                    done

                    if [ -d ${JOBS_DIR} ]; then
                        run_and_report_jobs
                        test -d ${RESULTS_DIR}  && mv ${RESULTS_DIR} ${RESULTS_DIR}_app
                        test -d ${JOBS_DIR}  && mv ${JOBS_DIR} ${JOBS_DIR}_app
                        [ ! -d $DISTRO ] && mkdir -p $DISTRO
                        test -d ${JOBS_DIR}_app && mv ${JOBS_DIR}_app $DISTRO
                        test -d ${RESULTS_DIR}_app && mv ${RESULTS_DIR}_app $DISTRO

                        if [ $? -ne 0 ] ;then
                            python parser.py -d $DISTRO
                            if [ ! -d ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO} ];then
                                mv ${DISTRO} ${GIT_DESCRIBE}/${RESULTS_DIR}/ && continue
                            else
                                cp -fr ${DISTRO}/* ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO}/ && continue
                            fi
                        fi

                        print_time "the end time of running app of $DISTRO is "
                    fi
                fi

            else
                # boot from NFS
                print_time "the start time of $boot_plan is "
                rm -fr ${JOBS_DIR} ${RESULTS_DIR}

                generate_jobs $boot_plan $DISTRO

                if [ -d ${JOBS_DIR} ]; then
                    if ! run_and_move_result $boot_plan $DISTRO ;then
                        if [ ! -d ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO} ];then
                            mv ${DISTRO} ${GIT_DESCRIBE}/${RESULTS_DIR} && continue
                        else
                            cp -fr ${DISTRO}/* ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO}/ && continue
                        fi
                    fi
                fi
                print_time "the end time of $boot_plan is "
            fi
        done
        if [ ! -d $GIT_DESCRIBE/${RESULTS_DIR}/${DISTRO} ];then
            mv ${DISTRO} $GIT_DESCRIBE/${RESULTS_DIR} && continue
        else
            cp -fr ${DISTRO}/* $GIT_DESCRIBE/${RESULTS_DIR}/${DISTRO}/ && continue
        fi
    done
    popd
}

function collect_result() {
    # push the binary files to the ftpserver
    pushd ${WORKSPACE}/local/ci-scripts/boot-app-scripts
    DES_DIR=${FTP_DIR}/${TREE_NAME}/${GIT_DESCRIBE}/
    [ ! -d $DES_DIR ] && echo "Don't have the images and dtbs" && exit -1

    tar czf test_result.tar.gz ${GIT_DESCRIBE}/*
    cp test_result.tar.gz  ${WORKSPACE}

    WHOLE_SUM='whole_summary.txt'
    if [  -e  ${WORKSPACE}/${WHOLE_SUM} ]; then
        rm -rf  ${WORKSPACE}/${WHOLE_SUM}
    fi
    mv ${CI_SCRIPTS_DIR}/boot-app-scripts/${WHOLE_SUM} ${GIT_DESCRIBE}/${RESULTS_DIR}/${WHOLE_SUM}
    cp ${GIT_DESCRIBE}/${RESULTS_DIR}/${WHOLE_SUM} ${WORKSPACE}/${WHOLE_SUM}
    cp -rf ${timefile} ${WORKSPACE} || true

    #zip -r ${{GIT_DESCRIBE}}_results.zip ${GIT_DESCRIBE}/*
    cp -f ${timefile} ${GIT_DESCRIBE} || true

    if [ -d $DES_DIR/${GIT_DESCRIBE}/results ];then
        sudo rm -fr $DES_DIR/${GIT_DESCRIBE}/results
        sudo rm -fr $DES_DIR/${GIT_DESCRIBE}/${timefile}
    fi

    sudo cp -rf ${GIT_DESCRIBE}/* $DES_DIR

    popd    # restore current work directory

    cat ${timefile}
    cat ${WORKSPACE}/${WHOLE_SUM}
}

function init_env() {
    CI_SCRIPTS_DIR=${WORKSPACE}/local/ci-scripts
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

    init_workspace
    init_build_option

    init_env
    init_boot_env

    init_input_params
    parse_params

    prepare_tools

    init_timefile
    print_time "the begin time of boot test is "
    init_summaryfile

    ##### copy some files to the lava-server machine to support the boot process #####
    parse_arch_map
    clean_workspace
    print_time "the time of preparing all envireonment is "
    trigger_lava_build
    collect_result

    save_to_properties
}

main "$@"
