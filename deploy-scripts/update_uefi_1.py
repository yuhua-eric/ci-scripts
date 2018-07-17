#!/usr/bin/python
import shell
import os
import argparse
import time
import re

def update_uefi(BMC_HOST,BMC_USER,BMC_PASS,UEFI_FILE,BMC_VERSION,BMC_PLAT):
    connection_command = 'ipmitool -H %s -I lanplus -U %s -P %s sol activate' % (BMC_HOST, BMC_USER, BMC_PASS)
    disconnction_command = 'ipmitool -H %s -I lanplus -U %s -P %s sol deactivate' % (BMC_HOST, BMC_USER, BMC_PASS)
    power_off_command = 'ipmitool -H %s -I lanplus -U %s -P %s power off' % (BMC_HOST, BMC_USER, BMC_PASS)
    power_on_command = 'ipmitool -H %s -I lanplus -U %s -P %s power on' % (BMC_HOST, BMC_USER, BMC_PASS)

    update_uefi_command = 'ipmcset -d upgrade -v /tmp/%s' % (UEFI_FILE)

    shell.run_command(disconnction_command.split(' '), allow_fail=True)
    time.sleep(3)
    shell.run_command(power_off_command.split(' '), allow_fail=True)
    time.sleep(5)

    print "start ipmi connection !"
    shell.run_command(power_on_command.split(' '), allow_fail=True)
    time.sleep(2)

    connection = shell.ipmi_connection(connection_command, 9000)
    connection.prompt_str = ['Upgrade successfully']
    connection.wait()
    print "uefi interrupt prompt find !"
    connection.sendline("#")
    # update uefi
    # depends on ftp
    connection.prompt_str = ['Move Highlight']
    connection.wait()
    print "uefi entry !"


def main(args):
    # COMMAND
    BMC_HOST = '192.168.2.135'
    BMC_USER = 'root'
    BMC_PASS = 'Huawei12#$'

    FTP_IP = '192.168.30.101'
    FTP_USER = 'yangyang'
    FTP_PASS = 'yangyang12#$'
    UEFI_FILE = 'UEFI_D05.hpm'

    if args.get("uefi") != "" or args.get("uefi") != None:
        UEFI_FILE = args.get("uefi")
    if args.get("host") != "" or args.get("host") != None:
        BMC_HOST = args.get("host")
    if args.get("ver") != "" or args.get("ver") != None:
        BMC_VERSION =  args.get("ver")
    if args.get("plat") != "" or args.get("plat") != None:
        BMC_PLAT =  args.get("plat")
    update_uefi(BMC_HOST,BMC_USER,BMC_PASS,UEFI_FILE,BMC_VERSION,BMC_PLAT)
    exit(0)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--uefi", help="uefi file name")
    parser.add_argument("--host", help="target host")
    parser.add_argument("--ver", help="uefi version")
    parser.add_argument("--plat", help="the platfrom of device")
    args = vars(parser.parse_args())
    main(args)
