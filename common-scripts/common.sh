#!/bin/bash -ex
#: Title                  : common.sh
#: Usage                  : source common.sh
#: Author                 : qinsl0106@thundersoft.com
#: Description            : 公共方法

# example usage
function common_usage() {
    __ORIGIN_PATH__="$PWD"
    script_path="${0%/*}"  # remove the script name ,get the path
    script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
    source "${script_path}/../common-scripts/common.sh"
}

######################################## help ########################################
#
# returns 0 if a variable is defined (set)
# returns 1 if a variable is unset
#
# e.g. : defined "A"
#
defined() {
    [[ "${!1-X}" == "${!1-Y}" ]]
}

#
# return 0 if a variable is undefined or value's length == 0
# return 1 otherwise
#
# e.g. : is_null_or_empty "A"
#
is_null_or_empty() {
    if defined "$1"; then
        if [ -z "${!1}" ]; then
            return 0
        else
            return 1
        fi
    else
        return 0
    fi
}

#
# echo the variable name and value to console
#
# e.g. : echo_vars "A" "B" "C"
#
echo_vars() {
    local vars=$@
    for var in $vars;do
        echo "[echo_vars] $var : ${!var}"
    done
}

#
# export all params variable
#
# e.g. : export_vars "A" "B" "C"
#
export_vars() {
    local vars=$@
    for var in $vars;do
        export $var
    done
}

init_timefile() {
    local target_name=$1
    if [ -z "${target_name}" ];then
        timefile=${WORKSPACE}/timestamp.log
    else
        timefile=${WORKSPACE}/timestamp_${target_name}.log
    fi
    if [ -f $timefile ]; then
        rm -fr $timefile
    else
        touch $timefile
    fi
}

print_time() {
    local time_variable_name=$1
    echo "${time_variable_name}="$(date "+%Y-%m-%d %H:%M:%S") >> $timefile
    echo "${time_variable_name}_second="$(date "+%s") >> $timefile
}

#
# These functions can be used for timing how long (a) command(s) take to
# execute.
#
# e.g. : start_time=$(now)
#      : end_time=$(now)
#
now() {
    echo $(date +%s)
}

#
# This function is used to calculate the elapsed time in second
#
# e.g. : start_time=$(now)
#      : end_time=$(now)
#
elapsed() {
    local START="$1"
    local STOP="$2"

    echo $(( STOP - START ))
}

#
# convert second to hour
#
# e.g. : second2std $elapsed_time
#
second2std() {
    local time=$1
    local seconds=$(( time % 60 ))
    time=$(( time - seconds ))
    local minute=$(( ( time % 3600 ) / 60 ))
    time=$(( time - ( minute * 60 ) ))
    local hour=$(( time / 3600 ))
    if [ ${hour} != "0" ]; then
        echo "${hour} hr ${minute} min ${seconds} sec"
    elif [ ${minute} != "0" ]; then
        echo "${minute} min ${seconds} sec"
    else
        echo "${seconds} sec"
    fi
}

######################################## logic ########################################

# prepare system tools
function prepare_tools() {
    dev_tools=$@

    if [ -x "$(command -v yum)" ] ; then
        echo "YUM"
        #yum -y update
        yum -y install ${dev_tools} || true
    elif [ -x "$(command -v apt-get)" ] ; then
        echo "APT_GET"
        #apt-get update
        apt-get install -y ${dev_tools} || true
    fi
}
