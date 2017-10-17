#!/bin/bash -ex
__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
cd "${script_path}"

function do_deploy() {
    # do deploy
    python deploy.py
    copy_ssh_id
}

function copy_ssh_id(){
    SSH_PASS=root
    SSH_USER=root
    SSH_IP=192.168.30.201

    sshpass -p ${SSH_PASS} ssh-copy-id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${SSH_IP}

}

do_deploy "$@"
