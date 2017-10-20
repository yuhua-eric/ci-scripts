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

FTP_IP = '192.168.30.101'
FTP_USER = 'yangyang'
FTP_PASS = 'yangyang12#$'
UEFI_FILE = 'UEFI_D05_Estuary.fd'


def update_uefi():
    connection_command = 'ipmitool -H %s -I lanplus -U %s -P %s sol activate' % (BMC_HOST, BMC_USER, BMC_PASS)
    disconnction_command = 'ipmitool -H %s -I lanplus -U %s -P %s sol deactivate' % (BMC_HOST, BMC_USER, BMC_PASS)
    power_off_command = 'ipmitool -H %s -I lanplus -U %s -P %s power off' % (BMC_HOST, BMC_USER, BMC_PASS)
    power_on_command = 'ipmitool -H %s -I lanplus -U %s -P %s power on' % (BMC_HOST, BMC_USER, BMC_PASS)

    update_uefi_command = 'provision %s -u %s -p %s -f %s -a 0x100000' % (FTP_IP, FTP_USER, FTP_PASS, UEFI_FILE)

    shell.run_command(disconnction_command.split(' '), allow_fail=True)
    time.sleep(3)
    shell.run_command(power_off_command.split(' '), allow_fail=True)
    time.sleep(5)

    print "start ipmi connection !"
    shell.run_command(power_on_command.split(' '), allow_fail=True)
    connection = shell.ipmi_connection(connection_command, 9000)
    connection.prompt_str = ['seconds to stop automatical booting']
    connection.wait()
    print "uefi interrupt prompt find !"
    connection.sendline("#")
    # update uefi
    # depends on ftp
    connection.prompt_str = ['Move Highlight']
    connection.wait()
    print "uefi entry !"

    operate(connection, 'down')
    operate(connection, 'down')
    operate(connection, 'enter')
    operate(connection, 'up')
    operate(connection, 'enter')

    connection.prompt_str = ['D05 >', 'Please send feedback']
    connection.wait()
    operate(connection, 'enter')

    connection.sendline(update_uefi_command)

    connection.prompt_str = ['Input the index:']
    connection.wait()
    connection.sendline("3")

    operate(connection, 'enter')

    connection.prompt_str = ['D05 >', 'succ!', 'WriteFlashCmd']
    connection.wait()
    operate(connection, 'enter')

    connection.sendline("spiwfmem 0x100000 0x0000000 0x300000")
    operate(connection, 'enter')
    connection.wait()

    operate(connection, 'enter')
    connection.wait()
    operate(connection, 'enter')

    time.sleep(3)
    connection.sendline("exit")
    connection.disconnect("close")

    shell.run_command(disconnction_command.split(' '), allow_fail=True)
    shell.run_command(power_off_command.split(' '), allow_fail=True)

def operate(connection, selector):
    KEY_UP = '\x1b[A'
    KEY_DOWN = '\x1b[B'
    KEY_RIGHT = '\x1b[C'
    KEY_LEFT = '\x1b[D'
    if selector == 'down':
        connection.raw_connection.send(KEY_DOWN, delay=10)
    elif selector == 'up':
        connection.raw_connection.send(KEY_UP, delay=10)
    elif selector == 'enter':
        connection.raw_connection.sendcontrol('M')
    elif selector == 'wait':
        connection.raw_connection.sendcontrol('M')


def main(args):
    if args.get("uefi") != "" or args.get("uefi") != None:
        UEFI_FILE = args.get("uefi")
    update_uefi()
    exit(0)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--uefi", help="uefi file name")
    args = vars(parser.parse_args())
    main(args)
