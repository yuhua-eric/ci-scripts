#!/bin/bash -ex


loop_time=${1:-"3"}
i=1
NEXT_SERVER='192.168.50.222'
function comfirm_scp() {

    timeout 120 sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${NEXT_SERVER} du -sh "/var/lib/lava/dispatcher/tmp/iso_install/arm64/estuary/daily_20180808/centos/d05/auto-install.iso"

}
time1=`date +%s`
time_begin=`expr $time1 / 60`
for((i=1;i<=${loop_time};i++));  
do
    timeout 120 sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${NEXT_SERVER} rm -rf "/var/lib/lava/dispatcher/tmp/iso_install/arm64/estuary/daily_20180808/centos/d05/"

    if timeout 120 sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${NEXT_SERVER} test -d "/var/lib/lava/dispatcher/tmp/pxe_install/arm64/estuary/daily_20180808/centos/d05/";then
        echo  "/var/lib/lava/dispatcher/tmp/iso_install/arm64/estuary/daily_20180808/centos/d05/ exist in ${NEXT_SERVER}"
    else
        timeout 120 sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${NEXT_SERVER} mkdir -p "/var/lib/lava/dispatcher/tmp/iso_install/arm64/estuary/daily_20180808/centos/"
        sshpass -p 'root' scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r "/tftp/iso_install/arm64/estuary/daily_20180808/centos/d05/" root@${NEXT_SERVER}:"/var/lib/lava/dispatcher/tmp/iso_install/arm64/estuary/daily_20180808/centos/" &
        sleep 1m
        wait
    fi 
   # du -sh auto-install.iso |sed -n '/7.2G/p'  > compile_tmp.log
    comfirm_scp | sed -n '/7.2G/p'  > compile_tmp.log
    if [ -s ./compile_tmp.log ] ; then
                echo "$i:pass" >> scp_result.txt
    else
                echo "$i:fail" >> scp_result.txt
    fi
    #i=`expr $i + 1`
done
time2=`date +%s`
time_end=`expr $time2 / 60`
test_time=`expr ${time_end} - ${time_begin}`
echo "the time cost is ${test_time} minute" >> scp_result.txt
cat scp_result.txt 
