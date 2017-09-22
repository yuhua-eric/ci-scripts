#!/usr/bin/python
import ConfigParser
import argparse
import fnmatch
import httplib
import os
import os.path
import re
import shutil
import subprocess
import urllib2
import urlparse
import yaml

from lib import configuration
from lib import utils
import parameter_parser

base_url = None
kernel = None
platform_list = []

d03 = {'device_type': 'd03',
    'templates': ['d03-arm64-kernel-ci-boot-template.yaml',
                              'd03-arm64-kernel-ci-boot-sata-template.yaml',
                              'd03-arm64-kernel-ci-boot-nfs-template.yaml',
                              'd03-arm64-kernel-ci-boot-pxe-template.yaml'],
    'defconfig_blacklist': ['arm64-allnoconfig',
                            'arm64-allmodconfig'],
                            'kernel_blacklist': [],
                            'nfs_blacklist': [],
                            'lpae': False,
                            'be': False,
                            'fastboot': False}
d05 = {'device_type': 'd05',
    'templates': ['d05-arm64-kernel-ci-boot-template.yaml',
                              'd05-arm64-kernel-ci-boot-sata-template.yaml',
                              'd05-arm64-kernel-ci-boot-nfs-template.yaml',
                              'd05-arm64-kernel-ci-boot-pxe-template.yaml'],
    'defconfig_blacklist': ['arm64-allnoconfig',
                            'arm64-allmodconfig'],
                            'kernel_blacklist': [],
                            'nfs_blacklist': [],
                            'lpae': False,
                            'be': False,
                            'fastboot': False}


dummy_ssh = {'device_type': 'dummy_ssh',
             'templates': [ 'dummy_ssh_template.yaml'],}

device_map = {
              'D03': [d03],
              'D05': [d05],
              }

parse_re = re.compile('href="([^./"?][^"?]*)"')

# add by wuyanjun  2016/3/9
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
            print 'error reading %s: %s' % (url, e)
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
            get_nfs_url(distro_url+direc, device_type)

# add by wuyanjun 2016-06-25
def get_pubkey():
    key_loc = os.path.join(os.path.expandvars('$HOME'), '.ssh', 'id_rsa.pub')

    if os.path.exists(key_loc):
        pubkey = open(key_loc, 'r').read().rstrip()
    else:
        path = os.getcwd()
        subprocess.call(os.path.join(path, "generate_keys.sh"), shell=True)
        try:
            pubkey = open(key_loc, 'r').read().rstrip()
        except Exception:
            pubkey = ""
    return pubkey

def generate_test_definition(github_url, test_path, name):
    test_definition =  "      - repository: " + github_url +"\n"
    test_definition += "        from: git\n"
    test_definition += "        path: " + test_path + "\n"
    test_definition += "        name: " + name + "\n"
    return test_definition

def generate_test_definitions(distro, device_type):
    # TODO : put it into parameters
    github_url = "https://github.com/qinshulei/ci-test-cases"
    # filter the test
    work_test_list=[]
    load_yaml = utils.load_yaml
    start_point = len(TEST_CASE_DEFINITION_DIR) + 1
    for file in TEST_CASE_DEFINITION_FILE_LIST:
        test_yaml = load_yaml(file)
        name = test_yaml['metadata']['name']
        ready = test_yaml['metadata']['ready']
        level = test_yaml['metadata']['level']
        print "name = " + str(name) + " " \
            "ready = " + str(ready) + " " \
            "level = " + str(level) + " "
        if ready == True and device_type.lower() in test_yaml['metadata']['devices'] and distro.lower() in test_yaml['metadata']['os']:
            test_path = file[start_point:]
            test_yaml['metadata']['test_path'] = test_path
            work_test_list.append(test_yaml)

    work_test_list = sorted(work_test_list, key = lambda x: x['metadata']['level'], reverse=True)

    all_definitions = ""
    for test in work_test_list:
        definition = generate_test_definition(github_url, test['metadata']['test_path'], test['metadata']['name'])
        all_definitions += definition

    return all_definitions

def create_jobs(base_url, kernel, plans, platform_list, targets, priority,
                distro_url, distro="Ubuntu"):
    print 'Creating YAML Job Files...'
    cwd = os.getcwd()
    url = urlparse.urlparse(kernel)
    build_info = url.path.split('/')
    image_url = base_url
    # TODO: define image_type dynamically
    image_type = 'kernel-ci'
    tree = build_info[1]
    kernel_version = build_info[2]
    defconfig = build_info[3]
    has_modules = True
    checked_modules = False

    pubkey = get_pubkey()
    for platform in platform_list:
        platform_name = platform.split('/')[-1].partition('_')[-1]
        for device in device_map[platform_name]:
            device_type = device['device_type']
            device_templates = device['templates']
            lpae = device['lpae']
            fastboot = device['fastboot']
            test_suite = None
            test_set = None
            test_desc = None
            test_type = None
            defconfigs = []
            for plan in plans:
                if 'boot' in plan or 'BOOT' in plan:
                    config = ConfigParser.ConfigParser()
                    try:
                        config.read(cwd + '/templates/' + plan + '/' + plan + '.ini')
                        test_suite = config.get(plan, 'suite')
                        test_set = config.get(plan, 'set')
                        test_desc = config.get(plan, 'description')
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

                    total_templates = []
                    config_plan = ConfigParser.ConfigParser()
                    config_plan.read(cwd + '/templates/' + plan + '/' + plan + '.ini')
                    if test_kind != "BOTH":
                        single_templates = []
                        both_templates = []
                        try:
                            single_templates = [ x for x in device_templates if \
                                    x.split(".json")[0] in \
                                    config_plan.get("TEST_KIND", test_kind).split(",")]
                        except:
                            print "There is no %s test cases" % test_kind
                        try:
                            both_templates = [ x for x in device_templates if \
                                    x.split(".json")[0] in \
                                    config_plan.get("TEST_KIND", 'BOTH').split(",")]
                        except:
                            print "There is no UT and ST test cases"
                        total_templates = list(set(single_templates).union(set(both_templates)))
                    else:
                        # may be need to improve here because of all test cases will be executed
                        total_templates = [x for x in device_templates]
                    # may need to change
                    get_nfs_url(distro_url, device_type)

                    # TODO : think filter the test job by platform, distro, device type, level, scope
                    test_definitions=generate_test_definitions(distro, device_type)

                    for template in total_templates:
                        job_name = tree + '-' + kernel_version + '-' + defconfig[:100] + \
                                '-' + platform_name + '-' + device_type + '-' + plan + '-' + distro
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
                                            tmp = tmp.replace('{device_type}', 'dummy_ssh'+'_'+device_type)
                                        else:
                                            tmp = tmp.replace('{device_type}', device_type)
                                        tmp = tmp.replace('{job_name}',\
                                                job_json.split("/")[-1].split(".yaml")[0])
                                        tmp = tmp.replace('{distro}', distro)
                                        # end by wuyanjun
                                        tmp = tmp.replace('{image_type}', image_type)
                                        tmp = tmp.replace('{image_url}', image_url)
                                        tmp = tmp.replace('{tree}', tree)
                                        if platform_name.endswith('.dtb'):
                                            tmp = tmp.replace('{device_tree}', platform_name)
                                        tmp = tmp.replace('{kernel_version}', kernel_version)
                                        if 'BIG_ENDIAN' in defconfig and plan == 'boot-be':
                                            tmp = tmp.replace('{endian}', 'big')
                                        else:
                                            tmp = tmp.replace('{endian}', 'little')
                                        # add by wuyanjun in 2016-06-25
                                        if pubkey:
                                            tmp = tmp.replace('{lava_worker_pubkey}', pubkey)

                                        tmp = tmp.replace('{defconfig}', defconfig)
                                        tmp = tmp.replace('{fastboot}', str(fastboot).lower())
                                        tmp = tmp.replace('{distro_name}', distro)
                                        # add by zhaoshijie, lava doesn't support centos in its source code,cheat it
                                        if 'boot' in plan or 'BOOT' in plan:
                                            tmp = tmp.replace('{target_type}', 'ubuntu')
                                        else:
                                            tmp = tmp.replace('{target_type}', str(distro).lower())
                                        tmp = tmp.replace('{device_type_upper}', str(device_type).upper())
                                        if plan:
                                            tmp = tmp.replace('{test_plan}', plan)
                                        if test_suite:
                                            tmp = tmp.replace('{test_suite}', test_suite)
                                        if test_set:
                                            tmp = tmp.replace('{test_set}', test_set)
                                        if test_desc:
                                            tmp = tmp.replace('{test_desc}', test_desc)
                                        if test_type:
                                            tmp = tmp.replace('{test_type}', test_type)
                                        if priority:
                                            tmp = tmp.replace('{priority}', priority.lower())
                                        else:
                                            tmp = tmp.replace('{priority}', 'high')

                                        if test_definitions:
                                            tmp = tmp.replace('{test_definitions}', test_definitions)

                                        fout.write(tmp)
                            # add by wuyanjun 2016/3/8
                            # to support filling all the nfsroot url in the json template
                            with open(job_json, 'rb') as temp:
                                whole_lines = temp.read()
                            if re.findall('nfs_url', whole_lines):
                                if len(distro_list):
                                    fill_nfs_url(job_json, distro_list, device_type)
                            else:
                                if re.findall('nfs_distro', whole_lines):
                                    rootfs_name = distro.lower()
                                    modified_file = job_json.split('.yaml')[0] + '-' + rootfs_name + '.yaml'
                                    with open(modified_file, 'wt') as fout:
                                        with open(job_json, "rt") as fin:
                                            for line in fin:
                                                tmp = line
                                                if re.search('{nfs_url}', tmp):
                                                    tmp = line.replace('{nfs_url}', distro)
                                                if re.search('{nfs_distro}', tmp):
                                                    tmp = line.replace('{nfs_distro}', rootfs_name)
                                                fout.write(tmp)
                                    if os.path.exists(job_json):
                                        os.remove(job_json)

# to fill the {nfs_url} instead of ${rootnfs_address_url}
def fill_nfs_url(job_json, distro_list, device_type):
    for distro in distro_list:
        rootfs = re.findall("(.*?).tar.gz", distro.split('/')[-1])
        rootfs_name = rootfs[0].split('_')[0].lower()
        modified_file = job_json.split('.yaml')[0] + '-' + rootfs_name + '.yaml'
        with open(modified_file, 'wt') as fout:
            with open(job_json, "rt") as fin:
                for line in fin:
                    tmp = line
                    if re.search('{nfs_url}', tmp):
                        tmp = line.replace('{nfs_url}', distro)
                    if re.search('{nfs_distro}', tmp):
                        tmp = line.replace('{nfs_distro}', rootfs_name)
                    fout.write(tmp)
            #print 'JSON Job created: jobs/%s' % modified_file.split('/')[-1]
    if os.path.exists(job_json):
        os.remove(job_json)

def walk_url(url, distro_url, plans=None, arch=None, targets=None,
            priority=None, distro="Ubuntu"):
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
                        priority, distro_url, distro)
            # Hack for subdirectories with arm64 dtbs
            if 'arm64' not in base_url:
                base_url = None
                kernel = None
            platform_list = []

    for dir in dirs:
        walk_url(url + dir, distro_url, plans, arch, targets, priority,\
                 distro)

def findAllTestCase(testDir):
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

def main(args):
    global test_kind
    global TEST_CASE_DEFINITION_DIR
    global TEST_CASE_DEFINITION_FILE_LIST

    config = configuration.get_config(args)

    TEST_CASE_DEFINITION_DIR = config.get("testDir")
    TEST_CASE_DEFINITION_FILE_LIST = findAllTestCase(TEST_CASE_DEFINITION_DIR)

    setup_job_dir(os.getcwd() + '/jobs')
    print 'Scanning %s for kernel information...' % config.get("url")
    distro = config.get("distro")
    if distro is None:
        distro = "Ubuntu"
    test_kind = config.get("testClassify")
    if test_kind is None:
        test_kind = "BOTH"
    walk_url(config.get("url"), config.get("url"), config.get("plans"),
            config.get("arch"), config.get("targets"), config.get("priority"),
            distro)
    print 'Done scanning for kernel information'
    print 'Done creating YAML jobs'
    exit(0)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("url", help="url to build artifacts")
    parser.add_argument("--config", help="configuration for the LAVA server")
    parser.add_argument("--section", default="default", help="section in the\
            LAVA config file")
    parser.add_argument("--plans", nargs='+', required=True, help="test plan\
            to create jobs for")
    parser.add_argument("--arch", help="specific the architecture to create jobs\
            for")
    parser.add_argument("--testDir", help="specific test case dir")
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
