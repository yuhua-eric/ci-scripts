#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
#    E-mail    :    wu.wu@hisilicon.com
#    Data      :    2016-03-02 11:44:33
#    Desc      :
import yaml
import os
from argparse import ArgumentParser

def read_value_of_array(filename, section, key, value):
    arrays = read_value_of_key(filename, section, key)
    #print arrays
    for arr in arrays:
        for item in arr.keys():
            if value==item:
                print arr[item]
                return arr[item]

def read_value_of_key(filename, section, key):
    sec = read_value_of_section(filename, section)
    if key not in sec.keys():
        return ''
    else:
        return sec[key]

def read_value_of_section(filename, section):
    with open(filename, 'r') as fp:
        dictionary = yaml.load(fp)
    if section not in dictionary.keys():
        return ''
    else:
        return dictionary[section]

if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument("-f", "--file", action="store",dest="filename",
            help="which file to parser")
    parser.add_argument("-s", "--sections", action="store",
        dest="section", help="which section to select")
    parser.add_argument("-k", "--key", action="store", dest="key",
            help="which key'value to be read")
    parser.add_argument("-v", "--value", action="store", dest="value",
            help="which value to be read")
    args = parser.parse_args()

    ci_env = os.environ['CI_ENV']
    print "CI_ENV : " + str(ci_env)
    if ci_env == None or ci_env == "":
        ci_env = "configs/dev/"
    elif ci_env == "dev":
        ci_env = "configs/dev/"
    elif ci_env == "test":
        ci_env = "configs/test/"
    else:
        print "Error: don't support this env"
        sys.exit(1)

    if args.filename and args.section:
        filename = ci_env + args.filename
        if not args.key and not args.value:
            value = read_value_of_section(filename, args.section)
            if type(value)==dict:
                for val in value.keys():
                    print val
                    print value[val]
            else:
                print value
        if args.key and not args.value:
            value = read_value_of_key(filename, args.section, args.key)
            if type(value)==list:
                for val in value:
                    print val
            else:
                print value
        if args.key and args.value:
            value = read_value_of_array(filename, args.section, args.key, args.value)
