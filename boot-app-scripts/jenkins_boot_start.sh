#!/bin/bash -ex
function init_build_option() {
    SKIP_LAVA_RUN=${SKIP_LAVA_RUN:-"false"}
}

function init_workspace() {
    WORKSPACE=${WORKSPACE:-/home/ts/jenkins/workspace/estuary-ci}
    mkdir -p ${WORKSPACE}
}

function init_input_params() {
    TREE_NAME=${TREE_NAME:-"open-estuary"}

    VERSION=${VERSION:-""}

    GIT_DESCRIBE=${GIT_DESCRIBE:-""}

    JENKINS_JOB_INFO=$(expr "${BUILD_URL}" : '^http.*/job/\(.*\)/$' | sed "s#/#-#g")
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

    WHOLE_SUM='whole_summary.txt'
    DETAILS_SUM='details_summary.txt'

    PDF_FILE='resultfile.pdf'
}

function generate_jobs() {
    test_name=$1
    distro=$2
    pwd
    for PLAT in $SHELL_PLATFORM; do
        board_arch=${dict[$PLAT]}
        if [ x"$distro" != x"" ]; then
            python estuary-ci-job-creator.py "$FTP_SERVER/${TREE_NAME}/${GIT_DESCRIBE}/${PLAT}-${board_arch}/" \
                   --tree "${TREE_NAME}" --plans "$test_name" --distro "$distro" --arch "${board_arch}" \
                   --testUrl "${TEST_REPO}" --testDir "${TEST_CASE_DIR}" --scope "${TEST_PLAN}" --level "${TEST_LEVEL}" \
                   --jenkinsJob "${JENKINS_JOB_INFO}"
        else
            python estuary-ci-job-creator.py "$FTP_SERVER/${TREE_NAME}/${GIT_DESCRIBE}/${PLAT}-${board_arch}/" \
                   --tree "${TREE_NAME}" --plans "$test_name" --arch "${board_arch}" \
                   --testUrl "${TEST_REPO}" --testDir "${TEST_CASE_DIR}"  --scope "${TEST_PLAN}" --level "${TEST_LEVEL}" \
                   --jekinsJob "${JENKINS_JOB_INFO}"
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
        else
            echo "POLL Result:"
            cat ${JOBS_DIR}/${RESULTS_DIR}/POLL
        fi

        python estuary-report.py --boot ${JOBS_DIR}/${RESULTS_DIR}/POLL --lab $LAVA_USER --testDir "${TEST_CASE_DIR}"
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

    [ -e ${WHOLE_SUM} ] && mv ${WHOLE_SUM} ${dest_dir}/
    [ -e ${DETAILS_SUM} ] && mv ${DETAILS_SUM} ${dest_dir}/
    [ -e ${PDF_FILE} ] && mv ${PDF_FILE} ${dest_dir}/

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

    ### reset CI scripts ####
    cd ${CI_SCRIPTS_DIR}/; git clean -fdx; cd -
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
            if [ "$boot_plan" = "BOOT_ISO" ]; then
                # TODO : need rewrite the logic by lava2 way to boot from STAT or SAS.
                :
            elif [ "$boot_plan" = "BOOT_PXE" ]; then
                # pxe install in previous step.use ssh to do the pxe test.
                # BOOT_NFS
                # boot from NFS
                print_time "the start time of $boot_plan is "
                generate_jobs $boot_plan $DISTRO

                if [ -d ${JOBS_DIR} ]; then
                    if ! run_and_move_result $boot_plan $DISTRO ;then
                        if [ ! -d ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO} ];then
                            mv ${DISTRO} ${GIT_DESCRIBE}/${RESULTS_DIR}
                            continue
                        else
                            cp -fr ${DISTRO}/* ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO}/
                            continue
                        fi
                    fi
                fi
                print_time "the end time of $boot_plan is "
            else
                # BOOT_NFS
                # boot from NFS
                print_time "the start time of $boot_plan is "
                generate_jobs $boot_plan $DISTRO

                if [ -d ${JOBS_DIR} ]; then
                    if ! run_and_move_result $boot_plan $DISTRO ;then
                        if [ ! -d ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO} ];then
                            mv ${DISTRO} ${GIT_DESCRIBE}/${RESULTS_DIR}
                            continue
                        else
                            cp -fr ${DISTRO}/* ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO}/
                            continue
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

    if [  -e  ${WORKSPACE}/${WHOLE_SUM} ]; then
        rm -rf  ${WORKSPACE}/${WHOLE_SUM}
    fi

    if [  -e  ${WORKSPACE}/${DETAILS_SUM} ]; then
        rm -rf  ${WORKSPACE}/${DETAILS_SUM}
    fi

    if [  -e  ${WORKSPACE}/${PDF_FILE} ]; then
        rm -rf  ${WORKSPACE}/${PDF_FILE}
    fi

    if [  -e  ${GIT_DESCRIBE}/${RESULTS_DIR}/${WHOLE_SUM} ]; then
        rm -rf  ${GIT_DESCRIBE}/${RESULTS_DIR}/${WHOLE_SUM}
    fi

    # echo '' | tee ${GIT_DESCRIBE}/${RESULTS_DIR}/${WHOLE_SUM} | tee ${GIT_DESCRIBE}/${RESULTS_DIR}/${DETAILS_SUM}

    cd ${GIT_DESCRIBE}/${RESULTS_DIR}
    distro_dirs=$(ls -d */ | cut -f1 -d'/')
    cd -

    for distro_name in ${distro_dirs};do
        # echo "##### distro : ${distro_name} ######" | tee -a ${GIT_DESCRIBE}/${RESULTS_DIR}/${WHOLE_SUM} | tee -a ${GIT_DESCRIBE}/${RESULTS_DIR}/${DETAILS_SUM}
        cat ${CI_SCRIPTS_DIR}/boot-app-scripts/${GIT_DESCRIBE}/${RESULTS_DIR}/${distro_name}/${WHOLE_SUM} >> ${GIT_DESCRIBE}/${RESULTS_DIR}/${WHOLE_SUM}
        cat ${CI_SCRIPTS_DIR}/boot-app-scripts/${GIT_DESCRIBE}/${RESULTS_DIR}/${distro_name}/${DETAILS_SUM} >> ${GIT_DESCRIBE}/${RESULTS_DIR}/${DETAILS_SUM}

        # cp -f ${CI_SCRIPTS_DIR}/boot-app-scripts/${GIT_DESCRIBE}/${RESULTS_DIR}/${distro_name}/${PDF_FILE} ${GIT_DESCRIBE}/${RESULTS_DIR}/${PDF_FILE}
    done

    # apt-get install pdftk
    # pdftk file1.pdf file2.pdf cat output output.pdf
    cp ${GIT_DESCRIBE}/${RESULTS_DIR}/${WHOLE_SUM} ${WORKSPACE}/${WHOLE_SUM}
    cp ${GIT_DESCRIBE}/${RESULTS_DIR}/${DETAILS_SUM} ${WORKSPACE}/${DETAILS_SUM}
    #cp ${GIT_DESCRIBE}/${RESULTS_DIR}/${PDF_FILE} ${WORKSPACE}/${PDF_FILE}

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
    TEST_CASE_DIR=${WORKSPACE}/local/ci-test-cases
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

function generate_failed_mail(){
    cd ${WORKSPACE}
    echo "${FAILED_MAIL_LIST}" > MAIL_LIST.txt
    echo "Estuary CI - ${GIT_DESCRIBE} - Failed" > MAIL_SUBJECT.txt
    cat > MAIL_CONTENT.txt <<EOF
( This mail is send by Jenkins automatically, don't reply )
Project Name: ${TREE_NAME}
Version: ${GIT_DESCRIBE}
Build Status: success
Boot and Test Status: failed
Build Log Address: ${BUILD_URL}console
Build Project Address: $BUILD_URL
Build and Generated Binaries Address:${FTP_SERVER}/open-estuary/${GIT_DESCRIBE}
The Test Cases Definition Address: ${TEST_REPO}

The boot and test is failed unexpectly. Please check the log and fix it.

EOF

}


function generate_success_mail(){
    cd ${WORKSPACE}
    if [ "${DEBUG}" = "true" ];then
        echo "${FAILED_MAIL_LIST}" > ${WORKSPACE}/MAIL_LIST.txt
    else
        echo "${SUCCESS_MAIL_LIST}" > ${WORKSPACE}/MAIL_LIST.txt
    fi

    echo "Estuary CI Auto-test Daily Report (${TODAY}) - ${GIT_DESCRIBE}" > ${WORKSPACE}/MAIL_SUBJECT.txt

    TODAY=$(date +"%Y/%m/%d")
    cat > ${WORKSPACE}/MAIL_CONTENT.txt <<EOF
Estuary CI Auto-test Daily Report (${TODAY}) <br>
<br>
1、构建信息<br>
Project Name: ${TREE_NAME} <br>
Version: ${GIT_DESCRIBE} <br>
Boot and Test Status: Success <br>
<br>
2. 今日构建结果 <br>
<a href="${BUILD_URL}console">Build Log Address</a> <br>
<a href="$BUILD_URL">Build Project Address</a><br>
<a href="${FTP_SERVER}/open-estuary/${GIT_DESCRIBE}">Build and Generated Binaries Address</a> <br>
<a href="${TEST_REPO}">The Test Cases Definition Address</a> <br>
<br>
3. 测试数据统计 <br>
<br>
EOF

    cd ${WORKSPACE}/local/ci-scripts/boot-app-scripts/${GIT_DESCRIBE}/${RESULTS_DIR}
    echo  ""
    echo "Test summary is below:<br>" >> ${WORKSPACE}/MAIL_CONTENT.txt
    echo '<table cellspacing="0" cellpadding="15px" border="1">' >> ${WORKSPACE}/MAIL_CONTENT.txt
    echo '<tr style="text-align: center;justify-content: center;background-color: #b9bbc0;"><th>Type</th><th>Total_Number</th><th>Failed_Number</th><th>Success_Number</th></tr>' >> ${WORKSPACE}/MAIL_CONTENT.txt
    cat whole_summary.txt | awk -F" " '{print "<tr style=\"text-align: center;justify-content: center;\">" "<td>" $1 "</td><td>" $2 "</td><td>" $3 "</td><td>" $4 "</td></tr>"}' >> ${WORKSPACE}/MAIL_CONTENT.txt
    echo "</table>" >> ${WORKSPACE}/MAIL_CONTENT.txt

    echo "<br>" >> ${WORKSPACE}/MAIL_CONTENT.txt

    echo  ""
    echo "The Test Case details is below:<br>" >> ${WORKSPACE}/MAIL_CONTENT.txt
    echo '<table cellspacing="0" cellpadding="15px" border="1">' >> ${WORKSPACE}/MAIL_CONTENT.txt
    echo '<tr style="text-align: center;justify-content: center;background-color: #b9bbc0;"><th>job_id</th><th>suite_name</th><th>case_name</th><th>case_result</th></tr>' >> ${WORKSPACE}/MAIL_CONTENT.txt
    cat details_summary.txt | awk -F" " '{print "<tr style=\"text-align: center;justify-content: center;\">" "<td>" $1 "</td><td>" $2 "</td><td>" $3 "</td><td>" $4 "</td></tr>"}' >> ${WORKSPACE}/MAIL_CONTENT.txt
    echo "</table>" >> ${WORKSPACE}/MAIL_CONTENT.txt

    echo "<br>" >> ${WORKSPACE}/MAIL_CONTENT.txt
    echo "4. 本月版本健康度统计<br>" >> ${WORKSPACE}/MAIL_CONTENT.txt
    cd -
}

function workaround_stash_devices_config() {
    if [ -n "${CI_ENV}" ];then
        :
    else
        CI_ENV=dev
    fi
    if [ -e "configs/"${CI_ENV}"/devices.yaml" ];then
        cp -f configs/"${CI_ENV}"/devices.yaml /tmp/devices.yaml
    fi
}

function workaround_pop_devices_config() {
    if [ -n "${CI_ENV}" ];then
        :
    else
        CI_ENV=dev
    fi

    if [ -e "/tmp/devices.yaml" ];then
        cp -f /tmp/devices.yaml configs/"${CI_ENV}"/devices.yaml
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

    generate_failed_mail

    prepare_tools

    init_timefile
    print_time "the begin time of boot test is "
    init_summaryfile

    ##### copy some files to the lava-server machine to support the boot process #####
    parse_arch_map
    clean_workspace
    print_time "the time of preparing all envireonment is "

    workaround_stash_devices_config

    trigger_lava_build
    collect_result
    generate_success_mail

    save_to_properties
}

main "$@"
