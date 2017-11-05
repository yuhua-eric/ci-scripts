#!/bin/bash -e

all_devices=$(python configs/parameter_parser.py -f devices.yaml)

CI_ENV=${CI_ENV:-"dev"}

cat configs/${CI_ENV}/dhcpd.conf.template
for device in ${all_devices};do
    if [[ "${device}" != "dhcp" ]];then
        filename=$(python configs/parameter_parser.py -f devices.yaml -s ${device} -k filename)
        device_mac=$(python configs/parameter_parser.py -f devices.yaml -s ${device} -k mac)
        device_ip=$(python configs/parameter_parser.py -f devices.yaml -s ${device} -k ip)
        device_next_server=$(python configs/parameter_parser.py -f devices.yaml -s ${device} -k next-server)
        device_filename=$(python configs/parameter_parser.py -f devices.yaml -s ${device} -k ${filename})

        echo "host ${device} {"
        echo "  hardware ethernet ${device_mac};"
        echo "  fixed-address ${device_ip};"
        echo "  next-server ${device_next_server};"
        echo "  filename \"${device_filename}\";"
        echo "}"
    fi
done
