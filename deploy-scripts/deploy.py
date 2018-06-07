#!/usr/bin/python
import shell
import os
import argparse
import time
import re

# TODO : depends on the boot type and boot os ,set the autoinstall time.
# DEPLOY_TIME_OUT = 3000
# set 25 minutes, so that it can retry the deploy
# (* 35 60)2100
#DEPLOY_TIME_OUT = 2100
DEPLOY_TIME_OUT = 3600

def boot_device(DEPLOY_TYPE, BMC_HOST, BMC_USER, BMC_PASS):
    connection_command = 'ipmitool -H %s -I lanplus -U %s -P %s sol activate' % (BMC_HOST, BMC_USER, BMC_PASS)
    disconnction_command = 'ipmitool -H %s -I lanplus -U %s -P %s sol deactivate' % (BMC_HOST, BMC_USER, BMC_PASS)
    power_off_command = 'ipmitool -H %s -I lanplus -U %s -P %s power off' % (BMC_HOST, BMC_USER, BMC_PASS)
    power_on_command = 'ipmitool -H %s -I lanplus -U %s -P %s power on' % (BMC_HOST, BMC_USER, BMC_PASS)

    pxe_boot_command = 'ipmitool -H %s -I lanplus -U %s -P %s chassis bootdev pxe' % (BMC_HOST, BMC_USER, BMC_PASS)
    iso_boot_command = 'ipmitool -H %s -I lanplus -U %s -P %s chassis bootdev cdrom' % (BMC_HOST, BMC_USER, BMC_PASS)

    if DEPLOY_TYPE == "BOOT_PXE":
        shell.run_command(pxe_boot_command.split(' '), allow_fail=True)
        time.sleep(5)
        shell.run_command(pxe_boot_command.split(' '), allow_fail=True)
    elif DEPLOY_TYPE == "BOOT_ISO":
        shell.run_command(iso_boot_command.split(' '), allow_fail=True)
        time.sleep(5)
        shell.run_command(iso_boot_command.split(' '), allow_fail=True)
    else:
        print "ERROR: don't support this BOOT TYPE " + DEPLOY_TYPE
        exit(-1)
    time.sleep(5)

    # ensure the ipmi sol disconnect
    shell.run_command(disconnction_command.split(' '), allow_fail=True)
    time.sleep(5)
    shell.run_command(disconnction_command.split(' '), allow_fail=True)
    time.sleep(5)

    # restart the board
    shell.run_command(power_off_command.split(' '), allow_fail=True)
    time.sleep(5)
    shell.run_command(power_on_command.split(' '), allow_fail=True)
    time.sleep(5)

    print "start ipmi connection !"
    # set the install timeout 50 minutes. because lava action timeout is 1 hour
    connection = shell.ipmi_connection(connection_command, DEPLOY_TIME_OUT)
    # wait longer to wait connection stable
    time.sleep(10)
    # connection.prompt_str = ['seconds to stop automatical booting']
    # connection.wait()
    # print "uefi interrupt prompt find !"

    # don't wait grub. linaro install don't have grub
    # connection.prompt_str = ['GNU GRUB']
    # connection.wait()
    # print "grub interrupt prompt find !"

    # connection.prompt_str = ['on an aarch64']
    # connection.wait()
    # connection.sendline("")

    # TODO: retry login
    connection.prompt_str = ['login:']
    connection.wait()
    print "os login interrupt prompt find !"

    # TODO: test login
    # TODO : login the os and change sshd config to allow ssh root login
    connection.sendline("root")
    connection.prompt_str = ['Password:']
    connection.wait()
    connection.sendline("root")
    connection.sendline("")
    connection.sendline("")
    connection.sendline("")
    # TODO : change prompt as config
    connection.prompt_str = ['root@debian:~#', 'root@centos ~', 'root@ubuntu:', 'root@ubuntu:~#', 'root@localhost ~', 'root@unassigned-hostname:~#','linux-l2k5:~ #']
    connection.wait()

    # WORKAROUND: fix the root login sshd config
    # ubuntu 14.04
    connection.sendline('sed -i "s/PermitRootLogin without-password/PermitRootLogin yes/" /etc/ssh/sshd_config')
    # new ubuntu 16.04
    connection.sendline('sed -i "s/PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config')
    # centos
    connection.sendline('sed -i "s/#PermitRootLogin yes/PermitRootLogin yes/" /etc/ssh/sshd_config')

    connection.wait()
    connection.sendline("service sshd restart")
    connection.wait()
    connection.sendline("sleep 2")
    connection.wait()

    connection.disconnect("close")


def main(args):
    # COMMAND
    BMC_HOST = '192.168.2.169'
    BMC_USER = 'root'
    BMC_PASS = 'Huawei12#$'

    DEPLOY_TYPE = 'BOOT_NFS'

    if args.get("host") != "" or args.get("host") != None:
        BMC_HOST = args.get("host")

    if args.get("host") != "" or args.get("host") != None:
        DEPLOY_TYPE = args.get('type')

    boot_device(DEPLOY_TYPE, BMC_HOST, BMC_USER, BMC_PASS)
    exit(0)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", help="target host")
    parser.add_argument("--type", help="deploy type")
    args = vars(parser.parse_args())
    main(args)
