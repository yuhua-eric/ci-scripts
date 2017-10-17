#!/bin/bash

# prepare system tools
function prepare_tools() {
    dev_tools="sshpass ipmitool python-pip python-pexpect"

    if ! (dpkg-query -l $dev_tools >/dev/null 2>&1); then
        sudo apt-get update
        if ! (sudo apt-get install -y --force-yes $dev_tools); then
            echo "ERROR: can't install tools: ${dev_tools}"
            exit 1
        fi
    fi
}

prepare_tools
