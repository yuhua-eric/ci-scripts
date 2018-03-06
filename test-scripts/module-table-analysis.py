#!/usr/bin/python
# -*- coding=utf-8 -*-
#
# Author by : qinsl0106@thundersoft.com
import os
import re
import yaml
import argparse
import json
from common import common
from lib import utils

"""
generate the data

    "kernel", [
        ["xxx","developer","tester","total","pass rate","pass num","fail num","block num"]
    ],
    "virtualization",[
        ["xxx1","developer","tester","total","pass rate","pass num","fail num","block num"],
        ["xxx2","developer","tester","total","pass rate","pass num","fail num","block num"],
        ["xxx3","developer","tester","total","pass rate","pass num","fail num","block num"]
    ],
    "distribution",[
        ["xxx1","developer","tester","total","pass rate","pass num","fail num","block num"],
        ["xxx2","developer","tester","total","pass rate","pass num","fail num","block num"],
        ["xxx3","developer","tester","total","pass rate","pass num","fail num","block num"],
        ["xxx4","developer","tester","total","pass rate","pass num","fail num","block num"]
    ]
"""

def get_name_from_yaml(path_list, dir_name_lists, owner):
    if path_list is None:
        return ''

    for item in path_list:
        paths = item.split('/')
        with open(item, 'r') as f:
            data = yaml.load(f)
            if isinstance(data, dict):
                if data.has_key('metadata') and data['metadata'].has_key('name'):
                    module = paths[7]
                    submodule = paths[8]
                    owner_detail = get_owner_detail(owner, submodule)
                    if owner_detail is not -1:
                        dir_name_lists[module][submodule]["developer"] = owner[owner_detail][2],
                        dir_name_lists[module][submodule]["tester"] = owner[owner_detail][3]
                        dir_name_lists[module][submodule][data['metadata']['name']]  = {}
                    else:
                        dir_name_lists[module][submodule]["developer"] = ""
                        dir_name_lists[module][submodule]["tester"] = ""
                        dir_name_lists[module][submodule][data['metadata']['name']] = {}
    return dir_name_lists


def get_owner_detail(nlist, test_case):
    for n in range(len(nlist)):
        for i in range(len(nlist[n])):
            if nlist[n][i] == test_case:
                return n
    return -1


def is_pass(path_list, test_result):
    if path_list is None:
        return False
    name_list = []
    for item in path_list:
        with open(item, 'r') as f:
            data = yaml.load(f)

            if isinstance(data, dict):
                if data.has_key('metadata') and data['metadata'].has_key('name'):
                    name_list.append(data['metadata']['name'])

    for r in result:
        if r.has_key('suite') and r['suite'][2:] in name_list:
            if r.has_key('metadata') and r['metadata'].has_key('result'):
                print r['metadata']['result'] + ' ',

def get_owner_data(file):
    with open(file, 'r') as f:
        data = f.readlines()

    for l in range(len(data)):
        index = data[l].find('| :')
        if index is not -1:
            if l+1 <len(data):
                data = data[l+1: ]
            break
    owner = []
    for item in data:
        s = ''.join(item.split())
        s = s.split('|')[1:]
        owner.append(s)
    return owner


def get_all_dir_names(dir_list, test_case_definition_dir):
    dir_name = {}
    for item in dir_list:
        dir_name[item] = {}
        dir_list2 = os.listdir(test_case_definition_dir + "/" + item )
        if not os.path.isdir(test_case_definition_dir + "/" + item):
            continue
        for sub_dir in dir_list2:
            if not os.path.isdir(test_case_definition_dir + "/" + item + "/" + sub_dir):
                continue
            dir_name[item][sub_dir] = {}
    return dir_name


def main():
    # ./module-table-analysis.py -f /home/qinshulei/projects/huawei/githubs/test_result_dict.json -t /home/qinshulei/projects/huawei/githubs/test-definitions

    # get args
    parser = argparse.ArgumentParser(prog='PROG')
    parser.add_argument('-f', '--file', required=True,
                        help='The data file path to load.')
    parser.add_argument('-t', "--testDir", required=True, help="specific test case dir")

    # TODO : save result to a file
    parser.add_argument('-o', '--output_file', help='allow output the result to a file')
    config = vars(parser.parse_args())
    print config

    test_case_definition_dir = config.get("testDir") + "/" + common.TEST_DIR_BASE_NAME
    test_plan_definition_dir = config.get("testDir") + "/" + common.PLAN_DIR_BASE_NAME
    owner_file = config.get("testDir") + "/owner/owner.md"

    # test_result_dict.json
    result_file = config.get("file")
    yaml_list = common.find_all_test_case_by_search(test_case_definition_dir)

    dir_list = os.listdir(test_case_definition_dir)
    dir_name_lists = get_all_dir_names(dir_list, test_case_definition_dir)
    owner = get_owner_data(owner_file)

    # pre process ,from " to '
    dataform = ''
    with open(result_file, 'r') as f:
        for line in f:
            dataform += str(line).replace('\'', '\"')
    with open(result_file, 'w') as f:
        f.write(dataform)

    json_file = utils.load_json(result_file)
    print json_file
    name_dict = get_name_from_yaml(yaml_list, dir_name_lists, owner)

    for job_key in json_file:
        result = json_file[job_key]
        for item in result:
            if item.has_key('suite') and item['suite'] != 'lava':
                suit_name = item['suite'][2:]
                for key in name_dict.keys():
                    for sub_key in name_dict[key].keys():
                        for suite_key in name_dict[key][sub_key].keys():
                            if suite_key != "tester" and suite_key != "developer":
                                if suite_key == suit_name:
                                    name_dict[key][sub_key][suite_key][item["name"]] = item["result"]

    for job_key in json_file:
        result = json_file[job_key]
        #print owner
        for item in result:
            if item.has_key('suite') and item['suite'] != 'lava':
                suit_name = item['suite'][2:]
                for key in name_dict.keys():
                    for sub_key in name_dict[key].keys():
                        name_dict[key][sub_key]["total"] = 0
                        name_dict[key][sub_key]["pass"] = 0
                        name_dict[key][sub_key]["fail"] = 0
                        for suite_key in name_dict[key][sub_key].keys():
                            if suite_key != "tester" and suite_key != "developer" and suite_key != "total" and suite_key != "pass" and suite_key != "fail":
                                for case_key in name_dict[key][sub_key][suite_key].keys():
                                    name_dict[key][sub_key]["total"] += 1
                                    if name_dict[key][sub_key][suite_key][case_key] == "pass":
                                        name_dict[key][sub_key]["pass"] += 1
                                    if name_dict[key][sub_key][suite_key][case_key] == "fail":
                                        name_dict[key][sub_key]["fail"] += 1
    print name_dict


if __name__ == '__main__':
    main()
