#!/bin/bash -ex

function clean_last_n_day_dir() {
    local target_dir=$1
    local n_day=$2
    cd ${target_dir}
    DEL_DATE=$(date '+%Y%m%d' --date="-${n_day} day")
    echo ${DEL_DATE}
    rm -rf ./*${DEL_DATE}*
    cd -
}

clean_last_n_day_dir "/fileserver/open-estuary" 31
clean_last_n_day_dir "/tftp/pxe_install/arm64/estuary" 2
clean_last_n_day_dir "/tftp/iso_install/arm64/estuary" 2
