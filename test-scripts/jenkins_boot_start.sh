#!/bin/bash -ex
# -*- coding: utf-8 -*-

#: Title                  : jenkins_boot_start.sh
#: Usage                  : ./local/ci-scripts/test-scripts/jenkins_boot_start.sh -p env.properties
#: Author                 : qinsl0106@thundersoft.com
#: Description            : CI中 测试部分 的jenkins任务脚本

__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
source "${script_path}/../common-scripts/common.sh"

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
    : ${TEST_SCOPE:=`python configs/parameter_parser.py -f config.yaml -s Test -k Scope`}
    : ${TEST_REPO:=`python configs/parameter_parser.py -f config.yaml -s Test -k Repo`}
    : ${TEST_LEVEL:=`python configs/parameter_parser.py -f config.yaml -s Test -k Level`}

    : ${LAVA_SERVER:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k lavaserver`}
    : ${LAVA_USER:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k lavauser`}
    : ${LAVA_STREAM:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k lavastream`}
    : ${LAVA_TOKEN:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k TOKEN`}

    : ${LAVA_DISPLAY_URL:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k LAVA_DISPLAY_URL`}

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
TEST_SCOPE="${TEST_SCOPE}"
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

    # 2. 今日构建结果
    WHOLE_SUM='whole_summary.txt'

    # 3. 测试数据统计
    SCOPE_SUMMARY_NAME='scope_summary.txt'

    # 6. 详细测试结果
    DETAILS_SUM='details_summary.txt'

    RESULT_JSON="test_result_dict.json"

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
                   --testUrl "${TEST_REPO}" --testDir "${TEST_CASE_DIR}" --plan "${TEST_PLAN}" --scope "${TEST_SCOPE}" --level "${TEST_LEVEL}" \
                   --jenkinsJob "${JENKINS_JOB_INFO}"
        else
            python estuary-ci-job-creator.py "$FTP_SERVER/${TREE_NAME}/${GIT_DESCRIBE}/${PLAT}-${board_arch}/" \
                   --tree "${TREE_NAME}" --plans "$test_name" --arch "${board_arch}" \
                   --testUrl "${TEST_REPO}" --testDir "${TEST_CASE_DIR}" --plan "${TEST_PLAN}" --scope "${TEST_SCOPE}" --level "${TEST_LEVEL}" \
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

    [ -e ${SCOPE_SUMMARY_NAME} ] && mv ${SCOPE_SUMMARY_NAME} ${dest_dir}/
    [ -e ${PDF_FILE} ] && mv ${PDF_FILE} ${dest_dir}/

    [ -e ${RESULT_JSON} ] && mv ${RESULT_JSON} ${dest_dir}/

    [ -d ${JOBS_DIR} ] && mv ${JOBS_DIR} ${dest_dir}/${JOBS_DIR}_${test_name}
    [ -d ${RESULTS_DIR} ] && mv ${RESULTS_DIR} ${dest_dir}/${RESULTS_DIR}_${test_name}

    if [ "$ret_val" -ne 0 ]; then
        return -1
    else
        return 0
    fi
}

#######  Begining the tests ######

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
    rm -rf ${CI_SCRIPTS_DIR}/uef* || true

    rm -rf test_result.tar.gz || true
    rm -rf ${WORKSPACE}/*.txt || true
    rm -rf ${WORKSPACE}/*.log || true

    ### reset CI scripts ####
    cd ${CI_SCRIPTS_DIR}/; git clean -fdx; cd -
}

function trigger_lava_build() {
    pushd ${WORKSPACE}/local/ci-scripts/test-scripts
    mkdir -p ${GIT_DESCRIBE}/${RESULTS_DIR}
    for DISTRO in $SHELL_DISTRO; do
        if [ -d $DISTRO ];then
            rm -fr $DISTRO
        fi

        for boot_plan in $BOOT_PLAN; do
            rm -fr ${JOBS_DIR} ${RESULTS_DIR}

            # generate the boot jobs for all the targets
            if [ "$boot_plan" = "BOOT_ISO" ]; then
                # pxe install in previous step.use ssh to do the pxe test.
                # BOOT_ISO
                # boot from ISO
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
            elif [ "$boot_plan" = "BOOT_PXE" ]; then
                # pxe install in previous step.use ssh to do the pxe test.
                # BOOT_PXE
                # boot from PXE
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
            else
                # BOOT_NFS
                # boot from NFS
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

function tar_test_result() {
    pushd ${WORKSPACE}/local/ci-scripts/test-scripts
    tar czf test_result.tar.gz ${GIT_DESCRIBE}/*
    cp test_result.tar.gz  ${WORKSPACE}
    popd
}

function collect_result() {
    # push the binary files to the ftpserver
    pushd ${WORKSPACE}/local/ci-scripts/test-scripts
    DES_DIR=${FTP_DIR}/${TREE_NAME}/${GIT_DESCRIBE}/
    [ ! -d $DES_DIR ] && echo "Don't have the images and dtbs" && exit -1

    if [ -e  ${WORKSPACE}/${WHOLE_SUM} ]; then
        rm -rf  ${WORKSPACE}/${WHOLE_SUM}
    fi

    if [ -e  ${WORKSPACE}/${DETAILS_SUM} ]; then
        rm -rf  ${WORKSPACE}/${DETAILS_SUM}
    fi

    if [ -e  ${WORKSPACE}/${PDF_FILE} ]; then
        rm -rf  ${WORKSPACE}/${PDF_FILE}
    fi

    if [ -e  ${WORKSPACE}/${SCOPE_SUMMARY_NAME} ]; then
        rm -rf  ${WORKSPACE}/${SCOPE_SUMMARY_NAME}
    fi

    if [ -e  ${GIT_DESCRIBE}/${RESULTS_DIR}/${WHOLE_SUM} ]; then
        rm -rf  ${GIT_DESCRIBE}/${RESULTS_DIR}/${WHOLE_SUM}
    fi

    # echo '' | tee ${GIT_DESCRIBE}/${RESULTS_DIR}/${WHOLE_SUM} | tee ${GIT_DESCRIBE}/${RESULTS_DIR}/${DETAILS_SUM}

    cd ${GIT_DESCRIBE}/${RESULTS_DIR}
    distro_dirs=$(ls -d */ | cut -f1 -d'/')
    cd -

    for distro_name in ${distro_dirs};do
        # echo "##### distro : ${distro_name} ######" | tee -a ${GIT_DESCRIBE}/${RESULTS_DIR}/${WHOLE_SUM} | tee -a ${GIT_DESCRIBE}/${RESULTS_DIR}/${DETAILS_SUM}

        # add distro info in txt file
        sed -i -e 's/^/'"${distro_name}"' /' ${CI_SCRIPTS_DIR}/test-scripts/${GIT_DESCRIBE}/${RESULTS_DIR}/${distro_name}/${WHOLE_SUM}
        sed -i -e 's/^/'"${distro_name}"' /' ${CI_SCRIPTS_DIR}/test-scripts/${GIT_DESCRIBE}/${RESULTS_DIR}/${distro_name}/${DETAILS_SUM}

        cat ${CI_SCRIPTS_DIR}/test-scripts/${GIT_DESCRIBE}/${RESULTS_DIR}/${distro_name}/${WHOLE_SUM} >> ${GIT_DESCRIBE}/${RESULTS_DIR}/${WHOLE_SUM}
        cat ${CI_SCRIPTS_DIR}/test-scripts/${GIT_DESCRIBE}/${RESULTS_DIR}/${distro_name}/${DETAILS_SUM} >> ${GIT_DESCRIBE}/${RESULTS_DIR}/${DETAILS_SUM}
    done

    # apt-get install pdftk
    # pdftk file1.pdf file2.pdf cat output output.pdf
    cp ${GIT_DESCRIBE}/${RESULTS_DIR}/${WHOLE_SUM} ${WORKSPACE}/${WHOLE_SUM}
    cp ${GIT_DESCRIBE}/${RESULTS_DIR}/${DETAILS_SUM} ${WORKSPACE}/${DETAILS_SUM}

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
( This mail is send by Jenkins automatically, don't reply ) <br>
Project Name: ${TREE_NAME} <br>
Version: ${GIT_DESCRIBE} <br>
Boot and Test Status: failed <br>
Deploy Type: ${BOOT_PLAN} <br>
Build Log Address: ${BUILD_URL}console <br>
Build Project Address: $BUILD_URL <br>
Build and Generated Binaries Address:${FTP_SERVER}/open-estuary/${GIT_DESCRIBE} <br>
The Test Cases Definition Address: ${TEST_REPO}<br>
<br>
The boot and test is failed unexpectly. Please check the log and fix it.<br>
<br>
EOF

}

function generate_success_mail(){
    echo "###################### start generate mail ####################"

    # prepare parameters
    cd ${WORKSPACE}
    if [ "${DEBUG}" = "true" ];then
        echo "${FAILED_MAIL_LIST}" > ${WORKSPACE}/MAIL_LIST.txt
    else
        echo "${SUCCESS_MAIL_LIST}" > ${WORKSPACE}/MAIL_LIST.txt
    fi
    TODAY=$(date +"%Y/%m/%d")
    MONTH=$(date +"%Y%m")
    # JOB_RESULT --> DISTRO_RESULT --> MODULE_RESULT --> SUITE_RESULT --> CASE_RESULT
    # TODO : depends on all distro's result. PASS/FAIL
    JOB_RESULT=FAIL

    # echo all mail releated info
    echo_vars TODAY GIT_DESCRIBE JOB_RESULT TREE_NAME BOOT_PLAN BUILD_URL FTP_SERVER TEST_REPO

    echo "------------------------------------------------------------"

    cd ${WORKSPACE}/local/ci-scripts/test-scripts/
    # the result dir path ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO}/

    echo "Estuary CI Auto-test Daily Report (${TODAY}) - ${JOB_RESULT}" > ${WORKSPACE}/MAIL_SUBJECT.txt

    echo "<b>Estuary CI Auto-test Daily Report (${TODAY})</b><br>" > ${WORKSPACE}/MAIL_CONTENT.txt
    echo "<br>" >> ${WORKSPACE}/MAIL_CONTENT.txt
    echo "<br>" >> ${WORKSPACE}/MAIL_CONTENT.txt
    echo "<b>1. 构建信息</b><br>" >> ${WORKSPACE}/MAIL_CONTENT.txt

    JOB_INFO_VERSION="Estuary V5.0 - ${TODAY}"
    # TODO : the start time need read from file.
    JOB_INFO_SHA1="${GIT_DESCRIBE}"
    JOB_INFO_RESULT=${JOB_RESULT}
    JOB_INFO_START_TIME=$(date +"%Y/%m/%d %H:%M:%S")
    JOB_INFO_END_TIME=$(date +"%Y/%m/%d %H:%M:%S")
    export_vars JOB_INFO_VERSION JOB_INFO_SHA1 JOB_INFO_RESULT JOB_INFO_START_TIME JOB_INFO_END_TIME
    envsubst < ./html/1-job-info-table.json > ./html/1-job-info-table.json.tmp
    python ./html/html-table.py -f ./html/1-job-info-table.json.tmp >> ${WORKSPACE}/MAIL_CONTENT.txt
    rm -f ./html/1-job-info-table.json.tmp
    echo "<br><br>" >> ${WORKSPACE}/MAIL_CONTENT.txt

    echo "<b>2. 今日构建结果</b><br>" >> ${WORKSPACE}/MAIL_CONTENT.txt
    JOB_RESULT_VERSION="Estuary V5.0"
    JOB_RESULT_DATA=$(cat <<-END
    ["Ubuntu", "pass", "100", "50%", "50", "50", "0"],
    ["Debian", "pass", "100", "50%", "50", "50", "0"],
    ["CentOS", "pass", "100", "50%", "50", "50", "0"]
END
                   )
    export_vars JOB_RESULT_VERSION JOB_RESULT_DATA
    envsubst < ./html/2-job-result-table.json > ./html/2-job-result-table.json.tmp
    python ./html/html-table.py -f ./html/2-job-result-table.json.tmp >> ${WORKSPACE}/MAIL_CONTENT.txt
    rm -f ./html/2-job-result-table.json.tmp
    echo "<br><br>" >> ${WORKSPACE}/MAIL_CONTENT.txt

    echo "<b>3. 测试数据统计</b><br>" >> ${WORKSPACE}/MAIL_CONTENT.txt
    for DISTRO in $SHELL_DISTRO; do
        # if don't exist this scope result file skip it.
        if [ ! -e ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO}/${SCOPE_SUMMARY_NAME} ];then
           echo "Waining: ${SCOPE_SUMMARY_NAME} don't exist"
           continue
        fi
        echo "${DISTRO} 版本测试数据统计:" >> ${WORKSPACE}/MAIL_CONTENT.txt
        DISTRO_RESULT_DATA=$(cat ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO}/${SCOPE_SUMMARY_NAME})
        export_vars DISTRO_RESULT_DATA
        envsubst < ./html/3-distro-result-table.json > ./html/3-distro-result-table.json.tmp
        python ./html/html-table.py -f ./html/3-distro-result-table.json.tmp >> ${WORKSPACE}/MAIL_CONTENT.txt
        rm -f ./html/3-distro-result-table.json.tmp
        echo "<br>" >> ${WORKSPACE}/MAIL_CONTENT.txt
    done

    echo "<b>4. ${MONTH}月版本健康度统计</b><br>" >> ${WORKSPACE}/MAIL_CONTENT.txt
    HEALTH_RATE_VERSION="Estuary V5.0"
    HEALTH_RATE_COMPILE="100%"
    HEALTH_RATE_TEST="0%"
    HEALTH_RATE_LINT="100%"
    HEALTH_RATE_TOTAL="0%"
    export_vars HEALTH_RATE_VERSION HEALTH_RATE_COMPILE HEALTH_RATE_TEST HEALTH_RATE_LINT HEALTH_RATE_TOTAL
    envsubst < ./html/4-health-rate-table.json > ./html/4-health-rate-table.json.tmp
    python ./html/html-table.py -f ./html/4-health-rate-table.json.tmp >> ${WORKSPACE}/MAIL_CONTENT.txt
    rm -f ./html/4-health-rate-table.json.tmp
    echo "<br><br>" >> ${WORKSPACE}/MAIL_CONTENT.txt

    echo "<b>5. 构建结果访问</b><br>" >> ${WORKSPACE}/MAIL_CONTENT.txt
    JOB_LINK_COMPILE="${BUILD_URL}console"
    JOB_LINK_RESULT="${FTP_SERVER}/open-estuary/${GIT_DESCRIBE}"
    JOB_LINK_TEST_CASE="${TEST_REPO}"
    export_vars JOB_LINK_COMPILE JOB_LINK_RESULT JOB_LINK_TEST_CASE
    envsubst < ./html/5-job-link-table.json > ./html/5-job-link-table.json.tmp
    python ./html/html-table.py -f ./html/5-job-link-table.json.tmp >> ${WORKSPACE}/MAIL_CONTENT.txt
    rm -f ./html/5-job-link-table.json.tmp
    echo "<br><br>" >> ${WORKSPACE}/MAIL_CONTENT.txt

    # TODO : refactor to 2
    :<<-EOF
    ## 统计结果
    echo "<b>6. 统计结果:</b><br>" >> ${WORKSPACE}/MAIL_CONTENT.txt
    echo '<table cellspacing="0px" cellpadding="10px" border="1"  style="border: solid 1px black; border-collapse:collapse; word-break:keep-all; text-align:center;">' >> ${WORKSPACE}/MAIL_CONTENT.txt
    echo '<tr style="text-align:center; justify-content:center; background-color:#D2D4D5; text-align:center; font-size:15px; font-weight=bold;padding:0px,40px"><th>Distro</th><th>Type</th><th>Total Number</th><th>Failed Number</th><th>Success Number</th></tr>' >> ${WORKSPACE}/MAIL_CONTENT.txt
    cat ${GIT_DESCRIBE}/${RESULTS_DIR}/whole_summary.txt |
        awk -F" " '{print "<tr style=\"text-align: center;justify-content: center;font-size:12px;\">" "<td>" $1 "</td><td>" $2 "</td><td>" $3 "</td><td>" $4 "</td><td>" $5 "</td></tr>"}' >> ${WORKSPACE}/MAIL_CONTENT.txt
    echo "</table>" >> ${WORKSPACE}/MAIL_CONTENT.txt
    echo "<br><br>" >> ${WORKSPACE}/MAIL_CONTENT.txt
EOF

    ## 详细测试结果
    # TODO : the style need set in TD
    echo  ""
    echo "<b>6. 详细测试结果:</b><br>" >> ${WORKSPACE}/MAIL_CONTENT.txt
    echo '<table cellspacing="0px" cellpadding="10px" border="1"  style="border: solid 1px black; border-collapse:collapse; word-break:keep-all; text-align:center;">' >> ${WORKSPACE}/MAIL_CONTENT.txt
    echo '<tr style="text-align:center; justify-content:center; background-color:#D2D4D5; text-align:center; font-size:15px; font-weight=bold;padding:10px"><th style=\"padding:10px;\">发行版</th><th style=\"padding:10px;\">LAVA任务ID</th><th style=\"padding:10px;\">测试集</th><th style=\"padding:10px;\">测试用例</th><th style=\"padding:10px;\">测试结果</th></tr>' >> ${WORKSPACE}/MAIL_CONTENT.txt
    cat ${GIT_DESCRIBE}/${RESULTS_DIR}/details_summary.txt |
        awk -F" " '{print "<tr style=\"text-align: center;justify-content: center;font-size:12px;\">" "<td style=\"padding:10px;\">" $1 "</td><td style=\"padding:10px;\"><a href=\"" "'"${LAVA_DISPLAY_URL}/results/"'" $2 "\">" $2 "</a><td style=\"padding:10px;\">" substr($3,3,length($3)) "</td><td style=\"padding:10px;\">" $4 "</td><td style=\"padding:10px;\">" $5 "</td></tr>"}' >> ${WORKSPACE}/MAIL_CONTENT.txt
    echo "</table>" >> ${WORKSPACE}/MAIL_CONTENT.txt
    echo "<br><br>" >> ${WORKSPACE}/MAIL_CONTENT.txt

    ##  编译结果
    echo "<b>7. 编译结果</b><br>" >> ${WORKSPACE}/MAIL_CONTENT.txt
    cd -

    echo "######################################## generate mail success ########################################"
}

function workaround_stash_devices_config() {
    if [ -n "${CI_ENV}" ];then
        :
    else
        CI_ENV=dev
    fi
    if [ -e "${CI_SCRIPTS_DIR}/configs/${CI_ENV}/devices.yaml" ];then
        cp -f "${CI_SCRIPTS_DIR}/configs/${CI_ENV}/devices.yaml" /tmp/devices.yaml
    fi
}

function workaround_pop_devices_config() {
    if [ -n "${CI_ENV}" ];then
        :
    else
        CI_ENV=dev
    fi

    if [ -e "/tmp/devices.yaml" ];then
        cp -f /tmp/devices.yaml "${CI_SCRIPTS_DIR}/configs/${CI_ENV}/devices.yaml"
    fi
}

function main() {
    parse_input "$@"
    source_properties_file

    init_timefile test

    init_workspace
    init_build_option

    init_env
    init_boot_env

    init_input_params
    parse_params

    generate_failed_mail

    prepare_tools

    print_time "time_test_test_begin"
    init_summaryfile

    ##### copy some files to the lava-server machine to support the boot process #####
    parse_arch_map
    clean_workspace
    print_time "time_preparing_envireonment"

    workaround_stash_devices_config

    trigger_lava_build
    collect_result

    print_time "time_test_test_end"
    generate_success_mail

    save_to_properties
}

main "$@"
