#!/usr/bin/python
import ConfigParser
import argparse
import os
import os.path
import re
import urllib2
import urlparse
import yaml

from lib import configuration
from lib import utils

base_url = None
kernel = None
CONFIG = None
platform_list = []

# os:
# - android
# - ubuntu
# - debian
# - lede
# - fedora
# - centos
# - debian_installer
# - centos_installer
# - oe

d03 = {'device_type': 'd03',
       'templates': ['d03-arm64-kernel-ci-boot-nfs-template.yaml',
                     'd03-arm64-kernel-ci-boot-iso-template.yaml',
                     'd03-arm64-kernel-ci-boot-pxe-template.yaml']
}
d05 = {'device_type': 'd05',
    'templates': ['d05-arm64-kernel-ci-boot-nfs-template.yaml',
                  'd05-arm64-kernel-ci-boot-iso-template.yaml',
                  'd05-arm64-kernel-ci-boot-pxe-template.yaml']
}

dummy_ssh = {'device_type': 'dummy_ssh',
             'templates': [ 'dummy_ssh_template.yaml'],}

device_map = {
              'D03': [d03],
              'D05': [d05],
              }

parse_re = re.compile('href="([^./"?][^"?]*)"')

distro_list = []


def setup_job_dir(directory):
    print 'Setting up YAML output directory at: jobs/'
    if not os.path.exists(directory):
        os.makedirs(directory)
    print 'Done setting up YAML output directory'


def get_nfs_url(distro_url, device_type):
    parse_re = re.compile('href="([^./"?][^"?]*)"')
    if not distro_url.endswith('.tar.gz') or not distro_url.endswith('.gz'):
        try:
            html = urllib2.urlopen(distro_url, timeout=30).read()
        except IOError, e:
            print 'error reading %s: %s' % (distro_url, e)
            exit(1)
        if not distro_url.endswith('/'):
            distro_url += '/'
    else:
        html = distro_url
    files= parse_re.findall(html)
    dirs = []
    for name in files:
        if not name.endswith('/'):
            dirs += [name]
        if name.endswith('.tar.gz') and 'distro' in distro_url+name and device_type in distro_url+name:
            distro_list.append(distro_url+name)
        for direc in dirs:
            get_nfs_url(distro_url + direc, device_type)


def generate_test_definition(test_path, name):
    test_definition =  "      - repository: \"" + TEST_CASE_DEFINITION_URL +"\"\n"
    test_definition += "        from: git\n"
    test_definition += "        path: \"" + test_path + "\"\n"
    test_definition += "        name: \"" + name + "\"\n"
    return test_definition


def generate_test_definitions(distro, device_type,test_scope, test_level):
    # TODO : put it into parameters
    # filter the test
    work_test_list=[]
    load_yaml = utils.load_yaml
    start_point = len(TEST_CASE_DEFINITION_DIR) + 1
    test_definitions = []

    ## check all test
    for file in TEST_CASE_DEFINITION_FILE_LIST:
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

    all_definitions = []

    # put 5 test definition in one lava job.
    i = 0
    current_definition = ""
    for test in work_test_list:
        definition = generate_test_definition(test['metadata']['test_path'], test['metadata']['name'])
        current_definition += definition
        if i == 5:
            all_definitions.append(current_definition)
            current_definition = ""
            i = 0
        else:
            i += 1
    if current_definition != "":
        all_definitions.append(current_definition)

    return all_definitions


def generate_job_file2(cwd, defconfig, device_type, distro, kernel_version, plan, platform_name, priority, test_type,
                       total_templates, test_definitions, number):
    for template in total_templates:
        job_name = CONFIG.get("tree") + '-' + kernel_version + '-' + defconfig[:100] + \
                   '-' + platform_name + '-' + device_type + '-' + plan + '-' + distro + '-' + str(number)
        if template in dummy_ssh['templates']:
            job_json = cwd + '/jobs/' + job_name + '-' + template
        else:
            job_json = cwd + '/jobs/' + job_name + '.yaml'
        template_file = cwd + '/templates/' + plan + '/' + str(template)
        if os.path.exists(template_file):
            with open(job_json, 'wt') as fout:
                with open(template_file, "rt") as fin:
                    for line in fin:
                        tmp = line.replace('{dtb_url}', platform_name)
                        # add by wuyanjun
                        # if the jobs are not the boot jobs of LAVA, try to use the
                        # dummy_ssh as the board device, or use the ${board_type} itself.
                        if 'boot' not in plan and 'BOOT' not in plan:
                            tmp = tmp.replace('{device_type}', 'dummy_ssh' + '_' + device_type)
                        else:
                            if plan == 'BOOT_NFS':
                                tmp = tmp.replace('{device_type}', device_type)
                            else:
                                tmp = tmp.replace('{device_type}', device_type + "ssh")
                        tmp = tmp.replace('{job_name}', \
                                          CONFIG.get("jenkinsJob") + "-" + job_json.split("/")[-1].split(".yaml")[0])
                        tmp = tmp.replace('{distro}', distro.lower())
                        # end by wuyanjun
                        tmp = tmp.replace('{tree}', CONFIG.get("tree"))
                        if platform_name.endswith('.dtb'):
                            tmp = tmp.replace('{device_tree}', platform_name)
                        tmp = tmp.replace('{kernel_version}', kernel_version)
                        tmp = tmp.replace('{defconfig}', defconfig)
                        tmp = tmp.replace('{distro_name}', distro)
                        tmp = tmp.replace('{device_type_upper}', str(device_type).upper())
                        tmp = tmp.replace('{tree_name}', CONFIG.get("tree"))
                        if plan:
                            tmp = tmp.replace('{test_plan}', plan)
                        if test_type:
                            tmp = tmp.replace('{test_type}', test_type)
                        if priority:
                            tmp = tmp.replace('{priority}', priority.lower())
                        else:
                            tmp = tmp.replace('{priority}', 'high')
                        if test_definitions:
                            tmp = tmp.replace('{test_definitions}', test_definitions)
                        else:
                            tmp = tmp.replace('{test_definitions}', "# no test definitions")
                        fout.write(tmp)


def create_new_jobs(plans, platform_name, targets, priority, distro="Ubuntu", scope="*", level="5"):
    print 'Creating YAML Job Files...'
    cwd = os.getcwd()
    kernel_version = "16.12"
    defconfig = "d05-arm64"
    for device in device_map[platform_name]:
        device_type = device['device_type']
        device_templates = device['templates']
        test_type = None
        defconfigs = []
        for plan in plans:
        # TODO: don't have boot plan, fix it
            if 'boot' in plan or 'BOOT' in plan:
                config = ConfigParser.ConfigParser()
                try:
                    config.read(cwd + '/templates/' + plan + '/' + plan + '.ini')
                    test_type = config.get(plan, 'type')
                    defconfigs = config.get(plan, 'defconfigs').split(',')
                except:
                    print "Unable to load test configuration"
                    exit(1)
            if targets is not None and device_type not in targets:
                print '%s device type has been omitted. Skipping JSON creation.' % device_type
            else:
                # add by wuyanjun in 2016/5/28
                # add the profile of test cases, so only UT test case can be
                # executed or ST can be executed.
                for json in dummy_ssh['templates']:
                    device_templates.append(json)
                total_templates = [x for x in device_templates]
                config_plan = ConfigParser.ConfigParser()
                config_plan.read(cwd + '/templates/' + plan + '/' + plan + '.ini')
                # TODO : think filter the test job by platform, distro, device type, level, scope
                test_definitions = generate_test_definitions(distro, device_type, scope, level)

                number = 1
                for definitions in test_definitions:
                    generate_job_file2(cwd, defconfig, device_type, distro, kernel_version, plan, platform_name,
                                       priority, test_type, total_templates, definitions, number)
                    number += 1


def generate_job_file(cwd,
                      defconfig,
                      device_type,
                      distro,
                      distro_url,
                      image_url,
                      kernel,
                      kernel_version,
                      plan,
                      platform,
                      platform_name,
                      priority,
                      test_definitions,
                      test_type,
                      total_templates,
                      tree,
                      number):
    for template in total_templates:
        job_name = tree + '-' + kernel_version + '-' + defconfig[:100] + \
                   '-' + platform_name + '-' + device_type + '-' + plan + '-' + distro + '-' + str(number)
        if template in dummy_ssh['templates']:
            job_json = cwd + '/jobs/' + job_name + '-' + template
        else:
            job_json = cwd + '/jobs/' + job_name + '.yaml'
        template_file = cwd + '/templates/' + plan + '/' + str(template)
        if os.path.exists(template_file):
            with open(job_json, 'wt') as fout:
                with open(template_file, "rt") as fin:
                    for line in fin:
                        tmp = line.replace('{dtb_url}', platform)
                        tmp = tmp.replace('{kernel_url}', kernel)
                        # add by wuyanjun
                        # if the jobs are not the boot jobs of LAVA, try to use the
                        # dummy_ssh as the board device, or use the ${board_type} itself.
                        if 'boot' not in plan and 'BOOT' not in plan:
                            tmp = tmp.replace('{device_type}', 'dummy_ssh' + '_' + device_type)
                        else:
                            if plan == 'BOOT_NFS':
                                tmp = tmp.replace('{device_type}', device_type)
                            else:
                                tmp = tmp.replace('{device_type}', device_type + "ssh")

                        tmp = tmp.replace('{job_name}', \
                                          CONFIG.get("jenkinsJob") + "-" + job_json.split("/")[-1].split(".yaml")[0])

                        tmp = tmp.replace('{distro}', distro.lower())

                        # end by wuyanjun
                        tmp = tmp.replace('{image_url}', image_url)
                        tmp = tmp.replace('{tree}', tree)

                        if platform_name.endswith('.dtb'):
                            tmp = tmp.replace('{device_tree}', platform_name)
                        tmp = tmp.replace('{kernel_version}', kernel_version)

                        tmp = tmp.replace('{defconfig}', defconfig)
                        tmp = tmp.replace('{distro_name}', distro)

                        tmp = tmp.replace('{device_type_upper}', str(device_type).upper())

                        tmp = tmp.replace('{tree_name}', CONFIG.get("tree"))

                        if plan:
                            tmp = tmp.replace('{test_plan}', plan)

                        if test_type:
                            tmp = tmp.replace('{test_type}', test_type)
                        if priority:
                            tmp = tmp.replace('{priority}', priority.lower())
                        else:
                            tmp = tmp.replace('{priority}', 'high')

                        if test_definitions:
                            tmp = tmp.replace('{test_definitions}', test_definitions)
                        else:
                            tmp = tmp.replace('{test_definitions}', "# no test definitions")

                        if re.findall('nfs_url', tmp):
                            if len(distro_list):
                                nfs_url = ""
                                for distro_url in distro_list:
                                    if distro in distro_url:
                                        nfs_url = distro_url
                                tmp = line.replace('{nfs_url}', nfs_url)
                            else:
                                print 'error: need rootfs.tar.gz'
                                exit(1)

                        fout.write(tmp)
    return distro_url


def create_jobs(base_url, kernel, plans, platform_list, targets, priority,
                distro_url, distro="Ubuntu", scope="*", level="5"):
    print 'Creating YAML Job Files...'
    cwd = os.getcwd()
    image_url = base_url
    url = urlparse.urlparse(kernel)

    build_info = url.path.split('/')
    tree = build_info[1]
    kernel_version = build_info[2]
    defconfig = build_info[3]

    for platform in platform_list:
        platform_name = platform.split('/')[-1].partition('_')[-1]
        for device in device_map[platform_name]:
            device_type = device['device_type']
            device_templates = device['templates']
            test_type = None
            defconfigs = []
            for plan in plans:

                # TODO: don't have boot plan, fix it
                if 'boot' in plan or 'BOOT' in plan:
                    config = ConfigParser.ConfigParser()
                    try:
                        config.read(cwd + '/templates/' + plan + '/' + plan + '.ini')
                        test_type = config.get(plan, 'type')
                        defconfigs = config.get(plan, 'defconfigs').split(',')
                    except:
                        print "Unable to load test configuration"
                        exit(1)

                if targets is not None and device_type not in targets:
                    print '%s device type has been omitted. Skipping JSON creation.' % device_type
                else:
                    # add by wuyanjun in 2016/5/28
                    # add the profile of test cases, so only UT test case can be
                    # executed or ST can be executed.
                    for json in dummy_ssh['templates']:
                        device_templates.append(json)

                    total_templates = [x for x in device_templates]
                    config_plan = ConfigParser.ConfigParser()
                    config_plan.read(cwd + '/templates/' + plan + '/' + plan + '.ini')

                    # may need to change
                    get_nfs_url(distro_url, device_type)

                    # TODO : think filter the test job by platform, distro, device type, level, scope
                    test_definitions = generate_test_definitions(distro, device_type, scope , level)

                    number = 1
                    for definitions in test_definitions:
                        generate_job_file(cwd, defconfig, device_type,
                                          distro, distro_url, image_url, kernel,
                                          kernel_version, plan, platform, platform_name, priority,
                                          definitions, test_type, total_templates, tree, number)
                        number += 1


def walk_url(url, distro_url, plans=None, arch=None, targets=None,
            priority=None, distro="Ubuntu",scope="*", level="1"):
    global base_url
    global kernel
    global platform_list
    try:
        html = urllib2.urlopen(url, timeout=30).read()
    except IOError, e:
        print 'error fetching %s: %s' % (url, e)
        exit(1)
    if not url.endswith('/'):
        url += '/'
    files = parse_re.findall(html)
    dirs = []
    for name in files:
        if name.endswith('/'):
            dirs += [name]
        if arch is None:
            if 'bzImage' in name and 'x86' in url:
                kernel = url + name
                base_url = url
                platform_list.append(url + 'x86')
                platform_list.append(url + 'x86-kvm')
            if 'zImage' in name and 'arm' in url:
                kernel = url + name
                base_url = url
            if 'Image' in name and 'arm64' in url:
                kernel = url + name
                base_url = url
            if name.endswith('.dtb') and name in device_map:
                if (base_url and base_url in url) or (base_url is None):
                    platform_list.append(url + name)
        elif arch == 'x86':
            if 'bzImage' in name and 'x86' in url:
                kernel = url + name
                base_url = url
                platform_list.append(url + 'x86')
                platform_list.append(url + 'x86-kvm')
        elif arch == 'arm':
            if 'zImage' in name and 'arm' in url:
                kernel = url + name
                base_url = url
        elif arch == 'arm64':
            if 'Image' in name and 'arm64' in url:
                kernel = url + name
                base_url = url
            if name.startswith('Image') and name.partition('_')[2] in device_map:
                platform_list.append(url + name)
        if 'distro' in name:
            distro_url = url + name
    if kernel is not None and base_url is not None:
        if platform_list:
            print 'Found artifacts at: %s' % base_url
            create_jobs(base_url, kernel, plans, platform_list, targets,
                        priority, distro_url, distro, scope, level)
            # Hack for subdirectories with arm64 dtbs
            if 'arm64' not in base_url:
                base_url = None
                kernel = None
            platform_list = []

    for dir_name in dirs:
        walk_url(url + dir_name, distro_url, plans, arch, targets, priority,
                 distro, scope, level)


def find_all_test_case(testDir):
    test_case_yaml_file_list=[]
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
            print fname
    return test_case_yaml_file_list

def find_all_test_case_by_test_plan(testDir, planDir, plan):
    load_yaml = utils.load_yaml
    try:
        plan_yaml = load_yaml(planDir + "/" + plan + ".yaml")
    except(yaml.parser.ParserError, yaml.scanner.ScannerError) as e:
        print "Errors: wrong yaml syntax :\n %s" % e
        exit(1)

    test_case_yaml_file_list=[]

    if not ("tests" in plan_yaml and "automated" in  plan_yaml["tests"]):
        print "Errors: wrong yaml syntax :\n %s" % (planDir + "/" + plan + ".yaml")
        exit(1)
    for test in plan_yaml["tests"]["automated"]:
        test_case_yaml_file_list.append(CONFIG.get("testDir") +  "/" + test["path"])

    return test_case_yaml_file_list

def main(args):
    global test_kind

    global TEST_CASE_DEFINITION_DIR
    global TEST_PLAN_DEFINITION_DIR
    global TEST_CASE_DEFINITION_FILE_LIST
    global TEST_CASE_DEFINITION_URL

    global CONFIG

    CONFIG = configuration.get_config(args)

    TEST_CASE_DEFINITION_DIR = CONFIG.get("testDir") + "/auto-test"
    TEST_PLAN_DEFINITION_DIR = CONFIG.get("testDir") + "/plans"

    if CONFIG.get("plan") != None and CONFIG.get("plan") != "" and CONFIG.get("plan") != "*":
        TEST_CASE_DEFINITION_FILE_LIST = find_all_test_case_by_test_plan(TEST_CASE_DEFINITION_DIR, TEST_PLAN_DEFINITION_DIR, CONFIG.get("plan"))
    else:
        TEST_CASE_DEFINITION_FILE_LIST = find_all_test_case(TEST_CASE_DEFINITION_DIR)
        # TEST_PLAN_DEFINITION_FILE_LIST = find_all_test_case(TEST_CASE_DEFINITION_DIR)

    TEST_CASE_DEFINITION_URL = "https://github.com/qinshulei/ci-test-cases"
    if CONFIG.get("testUrl") != None and CONFIG.get("testUrl") != "":
        TEST_CASE_DEFINITION_URL = CONFIG.get("testUrl")

    setup_job_dir(os.getcwd() + '/jobs')
    print 'Scanning %s for kernel information...' % CONFIG.get("url")
    distro = CONFIG.get("distro")
    if distro is None:
        distro = "Ubuntu"
    test_kind = CONFIG.get("testClassify")
    if test_kind is None:
        test_kind = "BOTH"

    if CONFIG.get("tree") == "open-estuary":
        walk_url(CONFIG.get("url"), CONFIG.get("url"), CONFIG.get("plans"),
                 CONFIG.get("arch"), CONFIG.get("targets"), CONFIG.get("priority"),
                 distro, CONFIG.get("scope"), CONFIG.get("level"))
    elif CONFIG.get("tree") == "linaro":
        create_new_jobs(CONFIG.get("plans"), "D05", CONFIG.get("targets"), CONFIG.get("priority"), distro,
                        CONFIG.get("scope"), CONFIG.get("level"))
    print 'Done scanning for kernel information'
    print 'Done creating YAML jobs'
    exit(0)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("url", help="url to build artifacts")
    parser.add_argument("--jenkinsJob", help="jenkins job info")
    parser.add_argument("--tree", help="tree name")
    parser.add_argument("--config", help="configuration for the LAVA server")
    parser.add_argument("--section", default="default", help="section in the\
            LAVA config file")
    parser.add_argument("--plans", nargs='+', required=True, help="test plan\
            to create jobs for")
    parser.add_argument("--arch", help="specific the architecture to create jobs\
            for")

    parser.add_argument("--testDir", required=True, help="specific test case dir")
    parser.add_argument("--testUrl", help="specific test case dir")

    parser.add_argument("--plan", help="test case plan", default="*")
    parser.add_argument("--scope", help="test case group", default="*")
    parser.add_argument("--level", help="test case level", default="1")
    parser.add_argument("--targets", nargs='+', help="specific targets to create\
            jobs for")
    parser.add_argument("--priority", choices=['high', 'medium', 'low', 'HIGH',\
            'MEDIUM', 'LOW'],
                        help="priority for LAVA jobs")
    parser.add_argument("--distro", choices=['Ubuntu', 'OpenSuse', 'Debian', \
            'Fedora', 'CentOS'],
                        help="distro for sata deploying")
    # BOTH means the case are both UT and ST
    parser.add_argument('--testClassify', help="the argument to distinguish \
            which tests run", choices=['UT', "ST", "BOTH"])
    args = vars(parser.parse_args())
    main(args)
