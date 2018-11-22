#!/bin/bash 
#author yuhua-eric
set -x

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
    TARGET_IP=$(python /usr/local/bin/parameter_yaml.py -f devices.yaml -s ${TARGET_HOSTNAME} -k ip)
}

# comfirm os 
# add by yuhua 9513
function comfirm_os() {
    local SSH_PASS="root"
    local SSH_USER=root
    local SSH_IP=${TARGET_IP}

    timeout 120 sshpass -p ${SSH_PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${SSH_IP} cat /etc/os-release
}
# add by yuhua 9513
function clean_lava() {

    local SSH_PASS="root"
    local SSH_USER=root
    local SSH_IP=${TARGET_IP}

    timeout 120 sshpass -p ${SSH_PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${SSH_IP} rm -rf /lava-*
    timeout 120 sshpass -p ${SSH_PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${SSH_IP} rm -f /*.tar.gz
}

#add by yuhua,change dns config when os is ubuntu to fix resove problem.
function change_dns() {
    local SSH_PASS="root"
    local SSH_USER=root
    local SSH_IP=${TARGET_IP}

    timeout 120 sshpass -p ${SSH_PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${SSH_IP} sed -i "'/nameserver/i\nameserver 192.168.1.107' /etc/resolv.conf"
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
    # add by yuhua 9513
    os=$(python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k os)
    distro_version=$(python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k distro_version)
    clean_lava
    if [ $os = $DISTRO ] && [ $distro_version = $DISTRO_VERSION ]; then
        echo "pass the config_dhcp and deploy"
    else
        java -jar jenkins-cli.jar -s http://${JENKINS_URL}/ login
        java -jar jenkins-cli.jar -s http://${JENKINS_URL}/ build step_lava_config_dhcp -w -s -p TREE_NAME="${TREE_NAME}" -p HOST_NAME="${TARGET_HOSTNAME}" -p DISTRO="${DISTRO}" -p DISTRO_VERSION="${DISTRO_VERSION}" -p DEPLOY_TYPE="${DEPLOY_TYPE}"
        java -jar jenkins-cli.jar -s http://${JENKINS_URL}/ build step_lava_deploy_device -w -s -p TREE_NAME="${TREE_NAME}" -p HOST_NAME="${TARGET_HOSTNAME}" -p DISTRO="${DISTRO}" -p DISTRO_VERSION="${DISTRO_VERSION}" -p DEPLOY_TYPE="${DEPLOY_TYPE}"
        change_dns
        if [ "$?" = "0" ];then 
            if [ $DISTRO != oe ];then
                comfirm_os |grep -i "$DISTRO" >./tmp.txt
                if [ -s ./tmp.txt ] ; then
                    echo "already get the right os"
                    echo "write the lastest os and distro_version in yaml"
                    python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k os -w $DISTRO
                    python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k distro_version -w $DISTRO_VERSION    
                    python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_time -w 0
	        else
                    echo "fail the deploy,write the fail info into yaml file;if failed before cancel job"
                    fail_os=$(python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_os)
                    fail_version=$(python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_version)
                    if [ $fail_os = $DISTRO ] && [ $fail_version = $DISTRO_VERSION ]; then
                        fail_time=$(python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_time)
                        new_time=`expr $fail_time + 1`
                        python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_time -w $new_time
                    else
                        python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_os -w $DISTRO
                        python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_version -w $DISTRO_VERSION
                        python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_time -w 1
                    fi
                    fail_time=$(python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_time) 
                    if [ $fail_os = $DISTRO ] && [ $fail_version = $DISTRO_VERSION ] && [ "$fail_time" = "2" ];then
                        python /usr/local/bin/cancel_job.py --dut ${TARGET_HOSTNAME}
                    fi

	            #python /usr/local/bin/cancel_job.py --dut ${TARGET_HOSTNAME}
                fi
            else
                comfirm_os |grep -i "opensuse" >./tmp.txt
                if [ -s ./tmp.txt ] ; then
                    echo "already get the right os"
                    echo "write the lastest os and distro_version in yaml"
                    python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k os -w $DISTRO
                    python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k distro_version -w $DISTRO_VERSION
                    python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_time -w 0
                else
                    fail_os=$(python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_os)
                    fail_version=$(python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_version)
                    if [ $fail_os = $DISTRO ] && [ $fail_version = $DISTRO_VERSION ]; then
                        fail_time=$(python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_time)
                        new_time=`expr $fail_time + 1`
                        python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_time -w $new_time
                    else
                        python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_os -w $DISTRO
                        python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_version -w $DISTRO_VERSION
                        python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_time -w 1
                    fi
                    fail_time=$(python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_time)
                    if [ $fail_os = $DISTRO ] && [ $fail_version = $DISTRO_VERSION ] && [ "$fail_time" = "2" ];then
                        python /usr/local/bin/cancel_job.py --dut ${TARGET_HOSTNAME}
                    fi 
                    #python /usr/local/bin/cancel_job.py --dut ${TARGET_HOSTNAME}
                fi
            fi
	else
            fail_os=$(python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_os)
            fail_version=$(python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_version)
            if [ $fail_os = $DISTRO ] && [ $fail_version = $DISTRO_VERSION ]; then
                fail_time=$(python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_time)
                new_time=`expr $fail_time + 1`
                python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_time -w $new_time
            else
                python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_os -w $DISTRO
                python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_version -w $DISTRO_VERSION
                python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_time -w 1
            fi
            fail_time=$(python /usr/local/bin/parameter_yaml.py -f devices_os.yaml -s ${TARGET_HOSTNAME} -k fail_time)
            if [ $fail_os = $DISTRO ] && [ $fail_version = $DISTRO_VERSION ] && [ "$fail_time" = "2" ];then
                python /usr/local/bin/cancel_job.py --dut ${TARGET_HOSTNAME}
            fi
            #python /usr/local/bin/cancel_job.py --dut ${TARGET_HOSTNAME}
        fi 
    fi
  #  if [ $DISTRO = ubuntu ];then
  #      change_dns
  #  fi 
    # test
    # java -jar jenkins-cli.jar -s http://192.168.67.146:8080/ build test-trigger-by-restapi -w -v -p TREE_NAME="open-estuary"
    sleep 2
}

main "$@"
