#!/usr/bin/python
# -*- coding=utf-8 -*-
#
# Author by : qinsl0106@thundersoft.com
import os
import re
import yaml
import json

TEST_DIR = "test-definitions-master/auto-test"

def _decode_list(data):
    rv = []
    for item in data:
        if isinstance(item, unicode):
            item = item.encode('utf-8')
        elif isinstance(item, list):
            item = _decode_list(item)
        elif isinstance(item, dict):
            item = _decode_dict(item)
        rv.append(item)
    return rv

def _decode_dict(data):
    rv = {}
    for key, value in data.iteritems():
        if isinstance(key, unicode):
            key = key.encode('utf-8')
        if isinstance(value, unicode):
            value = value.encode('utf-8')
        elif isinstance(value, list):
            value = _decode_list(value)
        elif isinstance(value, dict):
            value = _decode_dict(value)
        rv[key] = value
    return rv


def find_all_test_case_by_search(testDir):
    test_case_yaml_file_list = []
    for root, dirs, files in os.walk(testDir):
        # exclude dirs
        dirs[:] = [os.path.join(root, d) for d in dirs]
        dirs[:] = [d for d in dirs if not re.match('.*\.git$', d)]

        # exclude/include files
        files = [os.path.join(root, f) for f in files]
        files = [f for f in files if not re.match('(.*\.sh$)|(.*\.bash$)', f)]
        files = [f for f in files if re.match('(.*\.yaml$)|(.*\.yml$)', f)]
        for fname in files:
            test_case_yaml_file_list.append(fname)
            #print fname
    return test_case_yaml_file_list




def find_all_test_case_by_test_plan(testDir, planDir, plan):
    test_plan_yaml_file_list = []
    for root, dirs, files in os.walk(planDir):
        # exclude dirs
        dirs[:] = [os.path.join(root, d) for d in dirs]
        dirs[:] = [d for d in dirs if not re.match('.*\.git$', d)]
        # exclude/include files
        files = [os.path.join(root, f) for f in files]
        files = [f for f in files if not re.match('(.*\.sh$)|(.*\.bash$)', f)]
        files = [f for f in files if re.match('(.*' + plan + '\.yaml$)|(.*' + plan + '\.yml$)', f)]
        for fname in files:
            test_plan_yaml_file_list.append(fname)

    if len(test_plan_yaml_file_list) == 0:
        print "Warning : no test definition in this plan!"
        return []

    if len(test_plan_yaml_file_list) > 1:
        print "Warning : more than 1 test plan found!"

    plan_yaml = ''

    try:
        with open(test_plan_yaml_file_list[0], 'r') as f:
            plan_yaml = yaml.load(f)
    except(yaml.parser.ParserError, yaml.scanner.ScannerError) as e:
        print "Errors: wrong yaml syntax :\n %s" % e
        exit(1)

    test_case_yaml_file_list=[]

    if not ("tests" in plan_yaml and "automated" in plan_yaml["tests"]):
        print "Errors: wrong yaml syntax :\n %s" % (planDir + "/" + plan + ".yaml")
        exit(1)
    for test in plan_yaml["tests"]["automated"]:
        # the test path contains auto-test or automated, so need remove the string in testDir
        test_case_yaml_file_list.append(os.path.dirname(testDir) + "/" + test["path"])
    return test_case_yaml_file_list


def find_all_test_case(plan, test_case_definition_dir, test_plan_definition_dir):
    if plan is not None and plan != "" and plan != "*":
        test_case_definition_file_list = find_all_test_case_by_test_plan(test_case_definition_dir,
                                                                         test_plan_definition_dir, plan)
    else:
        test_case_definition_file_list = find_all_test_case_by_search(test_case_definition_dir)
    return test_case_definition_file_list

    #centos, d05, *, 5, auto_path,
def filter_test_definitions(distro, device_type, test_scope, test_level,
                            test_case_definition_dir, test_case_definition_file_list):
    # TODO : put it into parameters
    # filter the test
    work_test_list = []

    start_point = len(test_case_definition_dir) + 1
    test_definitions = []

    ## check all test
    for file in test_case_definition_file_list:
        try:
            with open(file, 'r') as f:
                test_yaml = yaml.load(f)
        except(yaml.parser.ParserError, yaml.scanner.ScannerError) as e:
            print "warnings: wrong yaml syntax :\n %s" % e
            continue

        if not test_yaml or not 'metadata' in test_yaml:
            #print "warning : don't have metadata : " + str(file)
            continue

        if not 'format' in test_yaml['metadata']:
            print "warning : don't have metadata.format : " + str(file)
            continue

        if 'name' in test_yaml['metadata']:
            name = test_yaml['metadata']['name']
        else:
            name = "unknown"

        if 'ready' in test_yaml['metadata']:
            ready = test_yaml['metadata']['ready']
        else:
            ready = True

        if 'level' in test_yaml['metadata']:
            level = test_yaml['metadata']['level']
        else:
            level = 5

        if 'scope' in test_yaml['metadata']:
            scope = test_yaml['metadata']['scope']
        else:
            scope = "*"

        # print "name = " + str(name) + " " \
        #       "ready = " + str(ready) + " " \
        #       "level = " + str(level) + " " \
        #       "scope = " + str(scope) + " "

        if name in test_definitions:
            #print "warning: duplicate test definition name. skip it."
            continue
        elif " " in name:
            #print "warning: test definition name contains space. skip it."
            continue
        else:
            test_definitions.append(name)

        if test_scope.lower().strip() == "*" or test_scope.lower() in scope:
            pass
        else:
            continue

        if int(level) > 5 or (int(level) <= 5 and int(level) <= int(test_level)):
            pass
        else:
            continue

        if ready \
                and device_type.lower() in test_yaml['metadata']['devices'] \
                and distro.lower() in test_yaml['metadata']['os']:
            test_path = file[start_point:]
            test_yaml['metadata']['test_path'] = test_path
            work_test_list.append(test_yaml)

    work_test_list = sorted(work_test_list,
                            key=lambda x: x['metadata']['level'] if 'level' in x['metadata'] else 5,
                            reverse=True)
    return work_test_list


def load_json(file):
    with open(file,'r') as f:
        return json.load(f, object_hook=_decode_dict)

def get_name_from_yaml(path_list, dir_name_lists, owner, result):
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

def get_all_dir_names(dir_list):
    dir_name = {}
    for item in dir_list:
        dir_name[item] = {}
        dir_list2 = os.listdir(TEST_DIR + "/" + item )
        if not os.path.isdir(TEST_DIR + "/" + item):
            continue
        for sub_dir in dir_list2:
            if not os.path.isdir(TEST_DIR + "/" + item + "/" + sub_dir):
                continue
            dir_name[item][sub_dir] = {}

    return dir_name

#def analysis_list(yaml_list, result, dir_list):



yaml_list = find_all_test_case_by_search("/home/ts/PycharmProjects/Analysis/test-definitions-master/auto-test")

dir_list = os.listdir(TEST_DIR)
dir_name_lists = get_all_dir_names(dir_list)
owner = get_owner_data('owner.md')
json_file = load_json('/home/ts/PycharmProjects/Analysis/test_result_dict.json')
result = json_file['2154']
name_dict = get_name_from_yaml(yaml_list, dir_name_lists, owner, result)


for item in result:
    if item.has_key('suite') and item['suite'] != 'lava':
        suit_name = item['suite'][2:]
        for key in name_dict.keys():
            for sub_key in name_dict[key].keys():
                for suite_key in name_dict[key][sub_key].keys():
                    if suite_key != "tester" and suite_key != "developer":
                        if suite_key == suit_name:
                            name_dict[key][sub_key][suite_key][item["name"]] = item["result"]
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

#analysis_list(yaml_list, )


# for item in yaml_list:
#     for dir in dir_list:
#         if item.find(dir) is not -1:
#             #print dir
#             pass

    #centos, d05, *, 5, auto_path,
#yaml_list = filter_test_definitions('centos', 'd05', '*', 5, '/home/ts/PycharmProjects/Analysis/test-definitions-master/auto-test', yaml_list)

#print len(yaml_list)

#
#print name_list
#s = is_pass(yaml_list, result)
