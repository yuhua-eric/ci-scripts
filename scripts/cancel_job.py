#!/usr/bin/python
# -*- coding: utf-8 -*-

# <variable> = required
# [variable] = optional
# Usage ./canel_job.py dut
#author yu_hua1@hoperun.com
import argparse
import xmlrpclib
from utils import *

username = "admin"
token = "0p9a29zs4rq15xyaaw9eza9sa1hsdb8axx4p9fankh6j0304wrla08w9n7s9qghn2m8bnofcolbrng0sy0zzef7awwt6hjnajhmnoq5aj0ufxm4mqt7629d3fskcnm75" 
server = "http://192.168.50.122/RPC2/"

def cancel_job(device_to_cancel):
    job_id = ''
    devices_list = connection.scheduler.all_devices()
    print devices_list
    for dut in devices_list:
        if device_to_cancel in dut:
            job_id = dut[3]
            print job_id

    connection.scheduler.cancel_job(job_id)
    
def main(args):
    global connection
    url = validate_input(username, token, server)
    connection = connect(url)
    if args.get('dut') != '' or args.get('dut') != None:
        dut_to_cancel = args.get('dut')
        print args.get('dut')
    cancel_job(dut_to_cancel)
    exit(0)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--dut", help="dut to cancel lava job")
    args = vars(parser.parse_args())
    main(args)





