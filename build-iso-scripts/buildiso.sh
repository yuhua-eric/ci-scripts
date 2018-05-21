#!/bin/bash -ex
# depends:
# ubuntu
# apt-get install genisoimage
# apt-get install xorriso
# centos
# yum install genisoimage
# wget https://www.gnu.org/software/xorriso/xorriso-1.4.8.tar.gz
# tar -xzvf xorriso-1.4.8.tar.gz
# ./configure && make && make install

__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
source "${script_path}/../common-scripts/common.sh"

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

function init_input_params() {
    TREE_NAME=${TREE_NAME:-"open-estuary"}
    GIT_DESCRIBE=${GIT_DESCRIBE:-""}
}


function main() {
    parse_input "$@"
    source_properties_file "${PROPERTIES_FILE}"

    init_input_params

    ./centos_mkautoiso.sh "${GIT_DESCRIBE}"
    ./ubuntu_mkautoiso.sh "${GIT_DESCRIBE}"
    ./debian_mkautoiso.sh "${GIT_DESCRIBE}"
    ./fedora_mkautoiso.sh "${GIT_DESCRIBE}"
    ./opensuse_mkautoiso.sh "${GIT_DESCRIBE}"
}

main "$@"
