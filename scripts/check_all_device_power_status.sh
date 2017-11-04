#!/bin/bash

device_list=$(grep -iRh "^  bmc: " configs/ | cut -c 7-)
for device in ${device_list};do
    echo "device : ${device}"
    ipmitool -H "${device}" -I lanplus -U root -P Huawei12#$ power status
    ipmitool -H "${device}" -I lanplus -U root -P Huawei12#$ lan print | grep 'MAC Address'
done
