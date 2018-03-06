#!/usr/bin/python
# -*- coding=utf-8 -*-
#
# Author by : qinsl0106@thundersoft.com
import os
import yaml
import argparse
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

def get_name_from_yaml(path_list, dir_name_lists, owner, test_case_definition_dir):
    if path_list is None:
        return ''

    for item in path_list:
        paths = item[len(test_case_definition_dir):].split('/')
        with open(item, 'r') as f:
            data = yaml.load(f)
            if isinstance(data, dict):
                if data.has_key('metadata') and data['metadata'].has_key('name'):
                    module = paths[1]
                    submodule = paths[2]
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
        if nlist[n][1] == test_case:
            return n
    return -1

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
        s = item.replace(' ','')
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


def generate_module_result(result_file, test_dir):
    test_case_definition_dir = os.path.realpath(test_dir + "/" + common.TEST_DIR_BASE_NAME)
    test_plan_definition_dir = os.path.realpath(test_dir + "/" + common.PLAN_DIR_BASE_NAME)
    owner_file = test_dir + "/owner/owner.md"
    yaml_list = common.find_all_test_case_by_search(test_case_definition_dir)
    dir_list = os.listdir(test_case_definition_dir)
    dir_name_lists = get_all_dir_names(dir_list, test_case_definition_dir)
    owner = get_owner_data(owner_file)
    json_file = utils.load_json(result_file)
    name_dict = get_name_from_yaml(yaml_list, dir_name_lists, owner, test_case_definition_dir)
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
        # print owner
        for item in result:
            if item.has_key('suite') and item['suite'] != 'lava':
                suit_name = item['suite'][2:]
                for key in name_dict.keys():
                    name_dict[key]["total"] = 0
                    name_dict[key]["pass"] = 0
                    name_dict[key]["fail"] = 0
                    for sub_key in name_dict[key].keys():
                        if sub_key == "tester" or sub_key == "developer" or sub_key == "total" or sub_key == "pass" or sub_key == "fail":
                            continue
                        name_dict[key][sub_key]["total"] = 0
                        name_dict[key][sub_key]["pass"] = 0
                        name_dict[key][sub_key]["fail"] = 0
                        for suite_key in name_dict[key][sub_key].keys():
                            if suite_key == "tester" or suite_key == "developer" or suite_key == "total" or suite_key == "pass" or suite_key == "fail":
                                continue
                            for case_key in name_dict[key][sub_key][suite_key].keys():
                                name_dict[key][sub_key]["total"] += 1
                                name_dict[key]["total"] += 1
                                if name_dict[key][sub_key][suite_key][case_key] == "pass":
                                    name_dict[key][sub_key]["pass"] += 1
                                    name_dict[key]["pass"] += 1
                                if name_dict[key][sub_key][suite_key][case_key] == "fail":
                                    name_dict[key][sub_key]["fail"] += 1
                                    name_dict[key]["fail"] += 1
    result = ""
    for name_key in name_dict.keys():
        if name_key == "tester" or name_key == "developer" or name_key == "total" or name_key == "pass" or name_key == "fail":
            continue
        if name_dict[name_key]["total"] == 0:
            continue
        result += "\"%s\", [\n" % name_key
        for sub_key in name_dict[name_key].keys():
            if sub_key == "tester" or sub_key == "developer" or sub_key == "total" or sub_key == "pass" or sub_key == "fail":
                continue
            if name_dict[name_key][sub_key]["total"] == 0:
                continue
            result += "    [\"%s\",\"%s\",\"%s\",\"%s\",\"%.2f%%\",\"%s\",\"%s\",\"%s\"],\n" \
                      % ( sub_key,
                          name_dict[name_key][sub_key]["developer"], \
                          name_dict[name_key][sub_key]["tester"], \
                          str(name_dict[name_key][sub_key]["total"]), \
                          1.0 * name_dict[name_key][sub_key]["pass"] / name_dict[name_key][sub_key]["total"], \
                          str(name_dict[name_key][sub_key]["pass"]), \
                          str(name_dict[name_key][sub_key]["fail"]), \
                          str(name_dict[name_key][sub_key]["total"] - name_dict[name_key][sub_key]["fail"] -
                              name_dict[name_key][sub_key]["pass"]) )
        result = result.rstrip(",\n")
        result += "],\n"
    if len(result) > 0:
        result = result.rstrip(",\n")
    return result


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
    test_dir = config.get("testDir")
    # test_result_dict.json
    result_file = config.get("file")

    print generate_module_result(result_file, test_dir)

if __name__ == '__main__':
    main()
