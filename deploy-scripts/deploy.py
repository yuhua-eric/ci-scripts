#!/usr/bin/python
import shell
import os
import argparse
import time
import re

# COMMAND
BMC_HOST = '192.168.3.169'
BMC_USER = 'root'
BMC_PASS = 'Huawei12#$'
connection_command = 'ipmitool -H %s -I lanplus -U %s -P %s sol activate' % (BMC_HOST, BMC_USER, BMC_PASS)
disconnction_command = 'ipmitool -H %s -I lanplus -U %s -P %s sol deactivate' % (BMC_HOST, BMC_USER, BMC_PASS)
power_off_command = 'ipmitool -H %s -I lanplus -U %s -P %s power off' % (BMC_HOST, BMC_USER, BMC_PASS)
power_on_command = 'ipmitool -H %s -I lanplus -U %s -P %s power on' % (BMC_HOST, BMC_USER, BMC_PASS)

pxe_boot_command = 'ipmitool -H %s -I lanplus -U %s -P %s chassis bootdev pxe' % (BMC_HOST, BMC_USER, BMC_PASS)

def boot_device():
    shell.run_command(pxe_boot_command.split(' '), allow_fail=True)
    shell.run_command(disconnction_command.split(' '), allow_fail=True)
    shell.run_command(power_off_command.split(' '), allow_fail=True)
    time.sleep(1)
    print "start ipmi connection !"
    shell.run_command(power_on_command.split(' '), allow_fail=True)
    connection = shell.ipmi_connection(connection_command, 300)
    connection.prompt_str = ['seconds to stop automatical booting']
    connection.wait()
    print "uefi interrupt prompt find !"
    connection.prompt_str = ['GNU GRUB']
    connection.wait()
    print "grub interrupt prompt find !"

    connection.prompt_str = ['login:']
    connection.wait()
    print "os login interrupt prompt find !"
    connection.disconnect("close")
    # TODO: test login


def main(args):
    boot_device()
    exit(0)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", help="target host")
    args = vars(parser.parse_args())
    main(args)
