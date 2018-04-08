#!/bin/bash
# cd to tftp root dir
root_dirs=(pxe_install/arm64 iso_install/arm64)
versions=(estuary/v3.1 estuary/v500 linaro/16.12 estuary/current)

oss=(ubuntu centos debian)
boards=(d03 d05)

for root_dir in ${root_dirs[@]};do
    pushd .
    mkdir -p ${root_dir}
    cd ${root_dir}

    for version in ${versions[@]};do
        pushd .
        mkdir -p ${version}
        cd ${version}
        for os in ${oss[@]};do
            pushd .
            mkdir -p ${os}
            cd ${os}
            for board in ${boards[@]};do
                pushd .
                mkdir -p ${board}
                popd
            done
            popd
        done
        popd
    done
    popd
done
