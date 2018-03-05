#!/usr/bin/python
__author__ = 'qinshulei'

import os
import re
import yaml
from lib import utils

TEST_DIR_BASE_NAME = "auto-test"
PLAN_DIR_BASE_NAME = "plans"

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
            # print fname
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
        print "Warning : more than 1 test plan finded!"

    load_yaml = utils.load_yaml
    try:
        plan_yaml = load_yaml(test_plan_yaml_file_list[0])
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


def filter_test_definitions(distro, device_type, test_scope, test_level,
                            test_case_definition_dir, test_case_definition_file_list):
    # TODO : put it into parameters
    # filter the test
    work_test_list = []
    load_yaml = utils.load_yaml
    start_point = len(test_case_definition_dir) + 1
    test_definitions = []

    ## check all test
    for file in test_case_definition_file_list:
        try:
            test_yaml = load_yaml(file)
        except(yaml.parser.ParserError, yaml.scanner.ScannerError) as e:
            print "warnings: wrong yaml syntax :\n %s" % e
            continue

        if not test_yaml or not 'metadata' in test_yaml:
            print "warning : don't have metadata : " + str(file)
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

        print "name = " + str(name) + " " \
              "ready = " + str(ready) + " " \
              "level = " + str(level) + " " \
              "scope = " + str(scope) + " "

        if name in test_definitions:
            print "warning: duplicate test definition name. skip it."
            continue
        elif " " in name:
            print "warning: test definition name contains space. skip it."
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
