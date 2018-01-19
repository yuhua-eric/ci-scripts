#!/bin/bash -ex

function show_help(){
    echo "./lava_deploy_v2.sh -n open-estuary -d TARGET_HOSTNAME"
    exit 1
}

function parse_input() {
    # A POSIX variable
    OPTIND=1         # Reset in case getopts has been used previously in the shell.

    # Initialize our own variables:
    properties_file=""

    while getopts "h?l:n:d:o:v:t:" opt; do
        case "$opt" in
            h|\?)
                show_help
                exit 0
                ;;
            l)  JENKINS_URL="$OPTARG"
                JENKINS_URL=${JENKINS_URL:-"192.168.1.108:8080"}
                ;;
            n)  TREE_NAME="$OPTARG"
                TREE_NAME=${TREE_NAME:-"open-estuary"}
                ;;
            d)  TARGET_HOSTNAME="$OPTARG"
                TARGET_HOSTNAME=${TARGET_HOSTNAME:-"d05ssh01"}
                ;;
            o)  DISTRO="$OPTARG"
                DISTRO=${DISTRO:-"centos"}
                ;;
            v)  DISTRO_VERSION="$OPTARG"
                DISTRO_VERSION=${DISTRO_VERSION:-"v3.1"}
                ;;
            t)  DEPLOY_TYPE="$OPTARG"
                DEPLOY_TYPE=${DEPLOY_TYPE:-"BOOT_PXE"}
                ;;

        esac
    done

    shift $((OPTIND-1))
    # [ "$1" = "--" ] && shift
    JENKINS_URL=${JENKINS_URL:-"192.168.1.108:8080"}
    TREE_NAME=${TREE_NAME:-"open-estuary"}
    TARGET_HOSTNAME=${TARGET_HOSTNAME:-"d05ssh01"}
    DISTRO=${DISTRO:-"centos"}
    DISTRO_VERSION=${DISTRO_VERSION:-"v3.1"}
    DEPLOY_TYPE=${DEPLOY_TYPE:-"BOOT_PXE"}
}

function main(){
    parse_input "$@"

    if [ -e jenkins-cli.jar ];then
        :
    else
        # export JENKINS_URL=192.168.50.122:8080
        wget http://${JENKINS_URL}/jnlpJars/jenkins-cli.jar
    fi

    # need paste the public key
    java -jar jenkins-cli.jar -s http://${JENKINS_URL}/ login
    java -jar jenkins-cli.jar -s http://${JENKINS_URL}/ build step_lava_deploy_device -w -s -p TREE_NAME="${TREE_NAME}" -p HOST_NAME="${TARGET_HOSTNAME}" -p DISTRO="${DISTRO}" -p DISTRO_VERSION="${DISTRO_VERSION}" -p DEPLOY_TYPE="${DEPLOY_TYPE}"

    # test
    # java -jar jenkins-cli.jar -s http://192.168.67.146:8080/ build test-trigger-by-restapi -w -v -p TREE_NAME="open-estuary"

    sleep 2
}

main "$@"
