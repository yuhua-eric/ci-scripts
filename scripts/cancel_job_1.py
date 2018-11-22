#!/usr/bin/python
# -*- coding: utf-8 -*-

import xmlrpclib
import argparse
hostname = "192.168.50.122"
username = 'admin'
token = '0p9a29zs4rq15xyaaw9eza9sa1hsdb8axx4p9fankh6j0304wrla08w9n7s9qghn2m8bnofcolbrng0sy0zzef7awwt6hjnajhmnoq5aj0ufxm4mqt7629d3fskcnm75'
server = xmlrpclib.ServerProxy('http://%s:%s@%s/RPC2' % (username, token, hostname))

def cancel_job(dut):
    print 'the dut to cancel job is: %s' % dut
    job_id = ''
    dut_list = server.scheduler.all_devices()
    for device in dut_list:
        if dut in device:
            job_id = device[3]
            print 'the job id is :%s' % job_id
   
   server.scheduler.cancel_job(job_id)
   
   
def main(args)：
   if args.get("dut") != "" or args.get("dut") != None:
       dut = args.get("dut") 
       
   cancel_job(dut)   
   exit(0)
   
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--dut", help="target dut")
        args = vars(parser.parse_args())
    main(args)
