#!/usr/bin/python
import shell
import os
import argparse
import time
import re

BMC_HOST = '192.168.3.169'
connection_command = 'ipmitool -H %s -I lanplus -U root -P Huawei12#$ sol activate' % BMC_HOST
disconnction_command = 'ipmitool -H %s -I lanplus -U root -P Huawei12#$ sol deactivate' % BMC_HOST
power_off_command = 'ipmitool -H %s -I lanplus -U root -P Huawei12#$ power off' % BMC_HOST
power_on_command = 'ipmitool -H %s -I lanplus -U root -P Huawei12#$ power on' % BMC_HOST

def main(args):
    print connection_command
    exit(0)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", help="target host")
    args = vars(parser.parse_args())
    main(args)
