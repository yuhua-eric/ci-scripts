#!/usr/bin/python
# -*- coding: utf-8 -*-

# <variable> = required
# Usage ./lava-report.py <option> [json]
# pip install matplotlib
# pip install numpy
# pip install reportlab
import os
import xmlrpclib
import yaml
import argparse
import time
import re
import shutil
import matplotlib

matplotlib.use('Agg')

import matplotlib.pyplot as plt
import numpy as np
from lib import configuration
from lib import utils
from common import common

from reportlab.pdfgen.canvas import Canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Image, Table, TableStyle

# color
PASS_COLOR = "green"
FAIL_COLOR = "red"
BLOCK_COLOR = "yellow"

# for test report
WHOLE_SUMMARY_NAME = 'whole_summary.txt'
DETAILS_SUMMARY_NAME = 'details_summary.txt'

# TODO: add scope data pass result
SCOPE_SUMMARY_NAME = 'scope_summary.txt'

TEST_RESULT_FILE_NAME = "test_result_dict.json"
RESULT_PDF_FILENAME = 'resultfile.pdf'

job_result_dict = {}

device_map = {'d03': ['hip06-d03', 'hisi'],
              'd03ssh': ['d03ssh01', 'hisi'],
              'd05': ['d05_01', 'hisi'],
              'd05ssh': ['d05ssh01', 'hisi'],
              'ssh': ['ssh01', None],
              # 'dummy_ssh': ['hip05-d02', 'hisi'],
              'x86': ['x86', None],
              'dummy-ssh': ['dummy-ssh', None],
              'kvm': ['x86-kvm', None]}


def parse_yaml(yaml):
    jobs = utils.load_yaml(yaml)
    url = utils.validate_input(jobs['username'], jobs['token'], jobs['server'])
    connection = utils.connect(url)
    duration = jobs['duration']
    # Remove unused data
    jobs.pop('duration')
    jobs.pop('username')
    jobs.pop('token')
    jobs.pop('server')
    return connection, jobs, duration


# add by wuyanjun
def get_board_type(directory, filename):
    strinfo = re.compile('.txt')
    json_name = strinfo.sub('.json', filename)
    test_info = utils.load_json(os.path.join(directory, json_name))
    if 'board' in test_info.keys():
        # for dummy-ssh board
        board_type = ''
        try:
            if re.search('ssh', test_info['board_instance']):
                board_type = test_info['board_instance'].split('_')[0]
            else:
                if ',' in test_info['board']:
                    board_verify = test_info['board'].split(',')[0]
                    for key in device_map.keys():
                        if device_map[key][0] == board_verify:
                            board_type = key
                            break
                        else:
                            board_type = ''
                else:
                    # for dummy_ssh_{board_type}
                    board_type = test_info['board'].split('_')[-1]
        except KeyError:
            if ',' in test_info['board']:
                try:
                    board_verify = test_info['board'].split(',')[0]
                except:
                    board_verify = test_info['board']
                    for key in device_map.keys():
                        if device_map[key][0] == board_verify:
                            board_type = key
                            break
                        else:
                            board_type = ''
            else:
                # for jobs which has not incomplete
                board_type = test_info['board'].split('_')[-1]
        return board_type
    return ''


def get_plans(directory, filename):
    m = re.findall('[A-Z]+_?[A-Z]*', filename)
    if m:
        root_dir = directory
        while '.git' not in os.listdir(root_dir):
            root_dir = os.path.join(root_dir, os.path.pardir)
        root_dir = os.path.abspath(root_dir)
        for item in m:
            for root, dirs, files in os.walk(os.path.join(root_dir, "test-scripts", "templates")):
                for dir_item in dirs:
                    if dir_item == item:
                        return item
    return ''


def parser_and_get_result(contents, filename, directory, report_directory, connection):
    summary_post = '_summary.txt'
    if filename.endswith('.txt'):
        board_type = get_board_type(directory, filename)
        plan = get_plans(report_directory, filename)
        if board_type and plan:
            summary = board_type + '_' + plan + summary_post
        elif board_type:
            summary = board_type + summary_post
        elif plan:
            summary = plan + summary_post
        else:
            summary = 'summary.txt'
        with open(os.path.join(report_directory, summary), 'a') as sf:
            job_id = filename.split("_")[-1].split(".")[0]
            with open(os.path.join(directory, filename)) as fp:
                lines = fp.readlines()
            write_flag = 0
            # for job which has been run successfully
            with open(os.path.join(directory, filename)) as fp:
                contents = fp.read()
            if re.search("=+", contents) and re.search('Test.*?case.*?Result', contents):
                for i in range(0, len(lines)):
                    line = lines[i]
                    if write_flag == 1:
                        sf.write(line)
                        continue
                    if re.search("=+", line) and re.search("=+", lines[i + 2]) and re.search('Test.*?case.*?Result',
                                                                                             lines[i + 3]):
                        write_flag = 1
                        sf.write("job_id is: %s\n" % job_id)
                        sf.write(line)
                    sf.write('\n')
            # for jobs which is Incomplete
            else:
                job_details = connection.scheduler.job_details(job_id)
                job_name = re.findall('testdef.*\/(.*?)\.yaml', job_details['original_definition'])
                sf.write("job_id is: %s\n" % job_id)
                sf.write("=" * 13 + "\n")
                sf.write(' '.join(job_name) + "\n")
                sf.write("=" * 13 + "\n")
                sf.write(' '.join(job_name) + "_test_cases\t\tFAIL\n\n")


# add by zhangbp0704
# parser the test result by lava v2
def generate_test_report(job_id, connection):
    testjob_results = connection.results.get_testjob_results_yaml(job_id)
    # print testsuite_results
    test = yaml.load(testjob_results)
    if job_id not in job_result_dict:
        job_result_dict[job_id] = test


# generate pie chart
def print_base_info_pie_chart(result_dict, description):
    # summary suite
    suite_dict = {}
    for suite in result_dict.keys():
        print suite
        for situation in result_dict[suite]:
            if situation not in suite_dict:
                suite_dict[situation] = result_dict[suite][situation]
            else:
                value = suite_dict[situation]
                value = value + result_dict[suite][situation]
                suite_dict[situation] = value
    situation_list = []
    result_list = []

    # print it
    for key in sorted(suite_dict.keys()):
        result_list.append(suite_dict[key])
        situation_list.append(key)
    plt.axes(aspect=1)
    plt.title(description)
    plt.pie(x=result_list, labels=situation_list, autopct='%3.1f %%',
            shadow=True, labeldistance=1.1, startangle=90, pctdistance=0.6)
    plt.savefig("baseinfo_pie.jpg", dpi=120)
    plt.close()


# generate bar chart
def print_scope_info_bar_chart(result_dict, description):
    scope_list = []
    scope_list = sorted(result_dict.keys())

    pass_number_list = []
    for key in sorted(result_dict.keys()):
        pass_number_list.append(result_dict[key])

    plt.legend()
    x_pos = np.arange(len(scope_list))
    plt.bar(x_pos, pass_number_list, 0.35, facecolor='blue', edgecolor='white', align='center', alpha=0.4)
    plt.xticks(x_pos, scope_list)
    plt.xlabel("Scope")
    plt.ylabel("Pass Number")
    plt.title(description)
    plt.savefig("baseinfo_bar.jpg", dpi=120)
    plt.close()


def create_test_report_pdf(job_result_dict):
    # print job_result_dict
    story = []
    stylesheet = getSampleStyleSheet()

    normalStyle = stylesheet['Normal']
    curr_date = time.strftime("%Y-%m-%d", time.localtime())
    reportfilename = "Estuary-Test_Report-%s.pdf" % (curr_date)
    rpt_title = '<para autoLeading="off" fontSize=15 align=center><b>[ Estuary ] Test Report %s</b><br/><br/><br/></para>' % (
    curr_date)
    story.append(Paragraph(rpt_title, normalStyle))

    rpt_ps = '<para autoLeading="off" fontSize=8 align=center>( This mail is send by Jenkins automatically, don\'t reply )</para>'
    story.append(Paragraph(rpt_ps, normalStyle))

    text = '''<para autoLeading="off" fontSize=12><br /><font color=black>1.General Report</font><br /><br /></para>'''
    story.append(Paragraph(text, normalStyle))

    # pie image
    pieimg = Image('baseinfo_pie.jpg')
    pieimg.drawHeight = 320
    pieimg.drawWidth = 480
    story.append(pieimg)

    # calculate the pass number for each suit
    test_suite_dict = {}
    for job_id in job_result_dict.keys():
        for item in job_result_dict[job_id]:
            if item['suite'] not in test_suite_dict:
                test_suite_dict[item['suite']] = {}
                if item['result'] not in test_suite_dict[item['suite']]:
                    test_suite_dict[item['suite']][item['result']] = 1
                else:
                    value = test_suite_dict[item['suite']][item['result']]
                    value = value + 1
                    test_suite_dict[item['suite']][item['result']] = value
            else:
                if item['result'] not in test_suite_dict[item['suite']]:
                    test_suite_dict[item['suite']][item['result']] = 1
                else:
                    value = test_suite_dict[item['suite']][item['result']]
                    value = value + 1
                    test_suite_dict[item['suite']][item['result']] = value

    component_data = [['TestSuite', 'Passes', 'Fails', 'Totals']]
    for test_suite in sorted(test_suite_dict.keys()):
        passnum = 0
        failnum = 0
        if 'pass' in test_suite_dict[test_suite]:
            passnum = test_suite_dict[test_suite]['pass']
        if 'fail' in test_suite_dict[test_suite]:
            failnum = test_suite_dict[test_suite]['fail']
        totalnum = passnum + failnum
        data = [test_suite, passnum, failnum, totalnum]
        component_data.append(data)

    component_table = Table(component_data, colWidths=[150, 60, 60, 60])
    component_table.setStyle(TableStyle([
        ('FONTSIZE', (0, 0), (-1, -1), 8),  #font size
        ('BACKGROUND', (0, 0), (-1, 0), colors.lightskyblue),  #
        ('ALIGN', (-1, 0), (-2, 0), 'RIGHT'),  #
        ('VALIGN', (-1, 0), (-2, 0), 'MIDDLE'),  #
        ('LINEBEFORE', (0, 0), (0, -1), 0.1, colors.grey),  #
        ('TEXTCOLOR', (0, 1), (-2, -1), colors.black),  #
        ('GRID', (0, 0), (-1, -1), 0.5, colors.black),  #
    ]))
    story.append(component_table)

    text = '''<para autoLeading="off" fontSize=12><br /><font color=black>2.Test Suite Result Detail</font><br /><br /></para>'''
    story.append(Paragraph(text, normalStyle))
    component_data = [['JobID', 'Suite', 'Name', 'Result']]
    for job_id in sorted(job_result_dict.keys()):
        for item in sorted(job_result_dict[job_id], key=lambda x: x['suite']):
            if item['suite'] != 'lava':
                component_data.append([job_id, item['suite'], item['name'], item['result']])

    component_table = Table(component_data)
    component_table.setStyle(TableStyle([
        ('FONTSIZE', (0, 0), (-1, -1), 8),  #font size
        ('BACKGROUND', (0, 0), (-1, 0), colors.lightskyblue),  #
        ('ALIGN', (-1, 0), (-2, 0), 'RIGHT'),  #
        ('VALIGN', (-1, 0), (-2, 0), 'MIDDLE'),  #
        ('LINEBEFORE', (0, 0), (0, -1), 0.1, colors.grey),  #
        ('TEXTCOLOR', (0, 1), (-2, -1), colors.black),  #
        ('GRID', (0, 0), (-1, -1), 0.5, colors.black),  #
    ]))
    story.append(component_table)

    text = '''<para autoLeading="off" fontSize=12><br /><font color=black>3.Different Scope Pass Number</font><br /><br /></para>'''
    story.append(Paragraph(text, normalStyle))

    # bar image
    barimg = Image('baseinfo_bar.jpg')
    barimg.drawHeight = 320
    barimg.drawWidth = 480
    story.append(barimg)

    # generate pdf
    doc = SimpleDocTemplate(RESULT_PDF_FILENAME)
    doc.build(story)


# by job_result_dict get current test report by zhaofs0921
def generate_current_test_report():
    print "generate_current_test_report"
    suite_list = []  #all test suite list

    # test suite data
    test_suite_dict = {}
    test_scope_dict = {}

    #   Statistics of each test suite
    for job_id in job_result_dict.keys():
        for item in job_result_dict[job_id]:
            if item['suite'] not in test_suite_dict:
                test_suite_dict[item['suite']] = {}
                if item['result'] not in test_suite_dict[item['suite']]:
                    test_suite_dict[item['suite']][item['result']] = 1
                else:
                    value = test_suite_dict[item['suite']][item['result']]
                    value = value + 1
                    test_suite_dict[item['suite']][item['result']] = value
            else:
                if item['result'] not in test_suite_dict[item['suite']]:
                    test_suite_dict[item['suite']][item['result']] = 1
                else:
                    value = test_suite_dict[item['suite']][item['result']]
                    value = value + 1
                    test_suite_dict[item['suite']][item['result']] = value
    print_base_info_pie_chart(test_suite_dict, "Base Pass Rate Situation Chart")

    # scope data
    test_suite_scope_dict = {}
    for job_id in job_result_dict.keys():
        for item in job_result_dict[job_id]:
            if 'metadata' in item:
                metadata = item['metadata']
                if 'path' in metadata and 'repository' in metadata:
                    count_scope_pass_number(test_suite_scope_dict, metadata['path'], item['result'])
                elif 'extra' in metadata:
                    path = ""
                    repository = ""
                    for extra in metadata['extra']:
                        if 'path' in extra:
                            path = extra['path']
                            continue
                        if 'repository' in extra:
                            repository = extra['repository']
                            continue
                    if path != "" and repository != "":
                        count_scope_pass_number(test_suite_scope_dict, path, item['result'])
                    #    print test_suite_scope_dict
    print_scope_info_bar_chart(test_suite_scope_dict, "Pass Number Bar Chart")
    create_test_report_pdf(job_result_dict)

    current_test_result_dir = os.getcwd()

    test_result_file = os.path.join(current_test_result_dir, TEST_RESULT_FILE_NAME)
    if os.path.exists(test_result_file):
        os.remove(test_result_file)
    utils.write_json(TEST_RESULT_FILE_NAME, current_test_result_dir, job_result_dict)


def count_scope_pass_number(test_suite_scope_dict, path, result):
    # TODO : use parameters
    if TEST_CASE_DEFINITION_DIR:
        test_suite_dir = TEST_CASE_DEFINITION_DIR
    else:
        workspace = os.getenv("WORKSPACE")
        test_suite_dir = os.path.join(workspace, "local/ci-test-cases")

    yaml_file = utils.load_yaml(os.path.join(test_suite_dir, path))
    if not 'scope' in yaml_file['metadata']:
        # TODO : use default unknown scope for these test suit
        return

    for scope in yaml_file['metadata']['scope']:
        if result == 'pass':
            if scope not in test_suite_scope_dict:
                test_suite_scope_dict[scope] = 1
            else:
                value = test_suite_scope_dict[scope]
                value = value + 1
                test_suite_scope_dict[scope] = value


def generate_history_test_report():
    print "generate_history_test_report"


def boot_report(config):
    connection, jobs, duration = parse_yaml(config.get("boot"))
    # TODO: Fix this when multi-lab sync is working
    results_directory = os.getcwd() + '/results'
    results = {}
    utils.mkdir(results_directory)
    test_plan = None

    if config.get("lab"):
        report_directory = os.path.join(results_directory, config.get("lab"))
    else:
        report_directory = results_directory

    if os.path.exists(report_directory):
        shutil.rmtree(report_directory)
    utils.mkdir(report_directory)

    for job_id in jobs:
        print 'Job ID: %s' % job_id
        # Init
        boot_meta = {}
        arch = None
        board_instance = None
        boot_retries = 0
        kernel_defconfig_full = None
        kernel_defconfig = None
        kernel_defconfig_base = None
        kernel_version = None
        device_tree = None
        kernel_tree = None
        kernel_addr = None
        initrd_addr = None
        dtb_addr = None
        dtb_append = None
        job_file = ''
        board_offline = False
        kernel_boot_time = None
        boot_failure_reason = None
        efi_rtc = False
        # Retrieve job details
        device_type = ''
        job_details = connection.scheduler.job_details(job_id)
        if job_details['requested_device_type_id']:
            device_type = job_details['requested_device_type_id']
        if job_details['description']:
            job_name = job_details['description']
            try:
                job_short_name = re.search(".*?([A-Z]+.*)", job_name).group(1)
            except Exception:
                job_short_name = 'boot-test'
        try:
            device_name = job_details['_actual_device_cache']['hostname']
        except Exception:
            continue
        result = jobs[job_id]['result']
        bundle = jobs[job_id]['bundle']
        if not device_type:
            device_type = job_details['_actual_device_cache']['device_type_id']
        try:
            binary_job_file = connection.scheduler.job_output(job_id)
        except xmlrpclib.Fault:
            print 'Job output not found for %s' % device_type
            continue
        # Parse LAVA messages out of log
        raw_job_file = str(binary_job_file)
        for line in raw_job_file.splitlines():
            if 'Infrastructure Error:' in line:
                print 'Infrastructure Error detected!'
                index = line.find('Infrastructure Error:')
                boot_failure_reason = line[index:]
                board_offline = True
            if 'Bootloader Error:' in line:
                print 'Bootloader Error detected!'
                index = line.find('Bootloader Error:')
                boot_failure_reason = line[index:]
                board_offline = True
            if 'Kernel Error:' in line:
                print 'Kernel Error detected!'
                index = line.find('Kernel Error:')
                boot_failure_reason = line[index:]
            if 'Userspace Error:' in line:
                print 'Userspace Error detected!'
                index = line.find('Userspace Error:')
                boot_failure_reason = line[index:]
            if '<LAVA_DISPATCHER>' not in line:
                if len(line) != 0:
                    job_file += line + '\n'
            if 'rtc-efi rtc-efi: setting system clock to' in line:
                if device_type == 'dynamic-vm':
                    efi_rtc = True
        if not kernel_defconfig or not kernel_version or not kernel_tree:
            try:
                job_metadata_info = connection.results.get_testjob_metadata(job_id)
                kernel_defconfig = utils.get_value_by_key(job_metadata_info, 'kernel_defconfig')
                kernel_version = utils.get_value_by_key(job_metadata_info, 'kernel_version')
                kernel_tree = utils.get_value_by_key(job_metadata_info, 'kernel_tree')
                device_tree = utils.get_value_by_key(job_metadata_info, 'device_tree')
            except Exception:
                continue

        # Record the boot log and result
        # TODO: Will need to map device_types to dashboard device types
        if kernel_defconfig and device_type and result:
            if ( 'arm' == arch or 'arm64' == arch ) and device_tree is None:
                platform_name = device_map[device_type][0] + ',legacy'
            else:
                if test_plan == 'boot-nfs' or test_plan == 'boot-nfs-mp':
                    platform_name = device_map[device_type][0] + '_rootfs:nfs'
                else:
                    platform_name = device_map[device_type][0]

            # Create txt format boot metadata
            print 'Creating boot log for %s' % (platform_name + job_name + '_' + job_id)
            log = 'boot-%s.txt' % (platform_name + job_name + '_' + job_id)
            if config.get("lab"):
                directory = os.path.join(results_directory, kernel_defconfig + '/' + config.get("lab"))
            else:
                directory = os.path.join(results_directory, kernel_defconfig)
            utils.ensure_dir(directory)

            utils.write_file(job_file, log, directory)

            if kernel_boot_time is None:
                kernel_boot_time = '0.0'
            if results.has_key(kernel_defconfig):
                results[kernel_defconfig].append({'device_type': platform_name,
                                                  'job_id': job_id, 'job_name': job_short_name,
                                                  'kernel_boot_time': kernel_boot_time, 'result': result,
                                                  'device_name': device_name})
            else:
                results[kernel_defconfig] = [{'device_type': platform_name,
                                              'job_id': job_id, 'job_name': job_short_name,
                                              'kernel_boot_time': kernel_boot_time, 'result': result,
                                              'device_name': device_name}]

            # Create JSON format boot metadata
            print 'Creating JSON format boot metadata'
            if config.get("lab"):
                boot_meta['lab_name'] = config.get("lab")
            else:
                boot_meta['lab_name'] = None
            if board_instance:
                boot_meta['board_instance'] = board_instance
            boot_meta['retries'] = boot_retries
            boot_meta['boot_log'] = log
            # TODO: Fix this
            boot_meta['version'] = '1.0'
            boot_meta['arch'] = arch
            boot_meta['defconfig'] = kernel_defconfig_base
            if kernel_defconfig_full is not None:
                boot_meta['defconfig_full'] = kernel_defconfig_full
            if device_map[device_type][1]:
                boot_meta['mach'] = device_map[device_type][1]
            boot_meta['kernel'] = kernel_version

            boot_meta['job'] = kernel_tree
            boot_meta['board'] = platform_name
            if board_offline and result == 'FAIL':
                boot_meta['boot_result'] = 'OFFLINE'
                #results[kernel_defconfig]['result'] = 'OFFLINE'
            else:
                boot_meta['boot_result'] = result
            if result == 'FAIL' or result == 'OFFLINE':
                if boot_failure_reason:
                    boot_meta['boot_result_description'] = boot_failure_reason
                else:
                    boot_meta['boot_result_description'] = 'Unknown Error: platform failed to boot'
            boot_meta['boot_time'] = kernel_boot_time
            # TODO: Fix this
            boot_meta['boot_warnings'] = None
            if device_tree:
                if arch == 'arm64':
                    boot_meta['dtb'] = 'dtbs/' + device_map[device_type][1] + '/' + device_tree
                else:
                    boot_meta['dtb'] = 'dtbs/' + device_tree
            else:
                boot_meta['dtb'] = device_tree
            boot_meta['dtb_addr'] = dtb_addr
            boot_meta['dtb_append'] = dtb_append
            # TODO: Fix this
            boot_meta['initrd'] = None
            boot_meta['initrd_addr'] = initrd_addr
            if arch == 'arm':
                boot_meta['kernel_image'] = 'zImage'
            elif arch == 'arm64':
                boot_meta['kernel_image'] = 'Image'
            else:
                boot_meta['kernel_image'] = 'bzImage'
            boot_meta['loadaddr'] = kernel_addr
            json_file = 'boot-%s.json' % (platform_name + job_name + '_' + job_id)
            utils.write_json(json_file, directory, boot_meta)
            # add by wuyanjun
            parser_and_get_result(job_file, log, directory, report_directory, connection)

            #try to generate test_summary
            generate_test_report(job_id, connection)

    if results and kernel_tree and kernel_version:
        print 'Creating summary for %s' % (kernel_version)
        boot = '%s-boot-report.txt' % (kernel_version)
        if test_plan and ('boot' in test_plan or 'BOOT' in test_plan):
            boot = boot.replace('boot', test_plan)
        passed = 0
        failed = 0
        for defconfig, results_list in results.items():
            for result in results_list:
                if result['result'] == 'PASS':
                    passed += 1
                else:
                    failed += 1
        total = passed + failed
        with open(os.path.join(report_directory, boot), 'a') as f:
            f.write('Subject: %s boot: %s boots: %s passed, %s failed (%s)\n' % (kernel_tree,
                                                                                 str(total),
                                                                                 str(passed),
                                                                                 str(failed),
                                                                                 kernel_version))
            f.write('\n')
            f.write('Total Duration: %.2f minutes\n' % (duration / 60))
            f.write('Tree/Branch: %s\n' % kernel_tree)
            f.write('Git Describe: %s\n' % kernel_version)
            first = True
            for defconfig, results_list in results.items():
                for result in results_list:
                    if result['result'] == 'OFFLINE':
                        if first:
                            f.write('\n')
                            f.write('Boards Offline:\n')
                            first = False
                        f.write('\n')
                        f.write(defconfig)
                        f.write('\n')
                        break
                for result in results_list:
                    if result['result'] == 'OFFLINE':
                        f.write('    %s   %s   %s   %ss   %s: %s\n' % (result['job_id'],
                                                                       result['device_type'],
                                                                       result['device_name'],
                                                                       result['kernel_boot_time'],
                                                                       result['job_name'],
                                                                       result['result']))
                        f.write('\n')
            first = True
            for defconfig, results_list in results.items():
                for result in results_list:
                    if result['result'] == 'FAIL':
                        if first:
                            f.write('\n')
                            f.write('Failed Boot Tests:\n')
                            first = False
                        f.write('\n')
                        f.write(defconfig)
                        f.write('\n')
                        break
                for result in results_list:
                    if result['result'] == 'FAIL':
                        f.write('    %s   %s   %s   %ss   %s: %s\n' % (result['job_id'],
                                                                       result['device_type'],
                                                                       result['device_name'],
                                                                       result['kernel_boot_time'],
                                                                       result['job_name'],
                                                                       result['result']))
            f.write('\n')
            f.write('Full Boot Report:\n')
            for defconfig, results_list in results.items():
                f.write('\n')
                f.write(defconfig)
                f.write('\n')
                for result in results_list:
                    f.write('    %s   %s   %s   %ss   %s: %s\n' %
                            (result['job_id'],
                             result['device_type'],
                             result['device_name'],
                             result['kernel_boot_time'],
                             result['job_name'],
                             result['result']))


def generate_email_test_report(distro):
    print "--------------now begin get testjob: result ------------------------------"

    suite_list = []  #all test suite list
    case_dict = {}  #testcast dict value like 'smoke-test':[test-case1,test-case2,test-case3]
    boot_total = 0
    boot_success = 0
    boot_fail = 0
    test_total = 0
    test_success = 0
    test_fail = 0

    #get all the test suite list from get_testjob_results_yaml
    for job_id in job_result_dict.keys():
        for item in job_result_dict[job_id]:
            if suite_list.count(item['suite']) == 0:
                suite_list.append(item['suite'])

    #inital a no value dict
    for suite in suite_list:
        case_dict[suite] = []

    #set all the value in dict
    for job_id in job_result_dict.keys():
        for item in job_result_dict[job_id]:
            case_dict[item['suite']].append(item)
    #try to write summary file
    summary_dir = os.getcwd()
    summary_file = os.path.join(summary_dir, WHOLE_SUMMARY_NAME)
    if os.path.exists(summary_file):
        os.remove(summary_file)
    for key in sorted(case_dict.keys()):
        if key == 'lava':
            for item in case_dict[key]:
                if item['result'] == 'pass':
                    boot_total += 1
                    boot_success += 1
                elif item['result'] == 'fail':
                    boot_total += 1
                    boot_fail += 1
                else:
                    boot_total += 1
        else:
            for item in case_dict[key]:
                if item['result'] == 'pass':
                    test_total += 1
                    test_success += 1
                elif item['result'] == 'fail':
                    test_total += 1
                    test_fail += 1
                else:
                    test_total += 1

    with open(summary_file, 'w') as wfp:
        # ["Ubuntu", "pass", "100", "50%", "50", "50", "0"],
        wfp.write("[\"%s\", " % distro)
        # always pass for compile result
        wfp.write("{\"data\": \"%s\", \"color\": \"%s\"}, " %
                  ("pass", PASS_COLOR))
        wfp.write("\"%s\", " % str(test_total))
        if test_total == 0:
            wfp.write("\"%.2f%%\", " % (0.0))
        else:
            wfp.write("\"%.2f%%\", " % (100.0 * test_success / test_total))
        wfp.write("{\"data\": \"%s\", \"color\": \"%s\"}, " %
                  (str(test_success), PASS_COLOR))
        wfp.write("{\"data\": \"%s\", \"color\": \"%s\"}, " %
                  (str(test_fail), FAIL_COLOR))
        wfp.write("{\"data\": \"%s\", \"color\": \"%s\"}" %
                  (str(test_total - test_success - test_fail), BLOCK_COLOR))
        wfp.write("]")

    ## try to write details file
    details_dir = os.getcwd()
    details_file = os.path.join(details_dir, DETAILS_SUMMARY_NAME)
    if os.path.exists(details_file):
        os.remove(details_file)

    with open(details_file, "wt") as wfp:
        for job_id in sorted(job_result_dict.keys()):
            for item in sorted(job_result_dict[job_id], key=lambda x: x['suite']):
                if item['suite'] != 'lava':
                    wfp.write(job_id + "\t" + item['suite'] + '\t' +
                              item['name'] + '\t\t' + item['result'] + '\n')

    print "--------------now end get testjob result --------------------------"


def generate_scope_test_report(test_dir):
    template = generate_module_result(job_result_dict, test_dir)
    test_dir = os.getcwd()
    scope_file = os.path.join(test_dir, SCOPE_SUMMARY_NAME)
    if os.path.exists(scope_file):
        os.remove(scope_file)
    with open(scope_file, 'w') as wfp:
        wfp.write(str(template) + "\n")


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
                        dir_name_lists[module][submodule]["developer"] = owner[owner_detail][2]
                        dir_name_lists[module][submodule]["tester"] = owner[owner_detail][3]
                        dir_name_lists[module][submodule][data['metadata']['name']] = {}
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
            if l+1 < len(data):
                data = data[l+1:]
            break
    owner = []
    for item in data:
        s = item.replace(' ', '')
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


def generate_module_result(result_json_dict, test_dir):
    test_case_definition_dir = os.path.realpath(test_dir + "/" + common.TEST_DIR_BASE_NAME)
    test_plan_definition_dir = os.path.realpath(test_dir + "/" + common.PLAN_DIR_BASE_NAME)
    owner_file = test_dir + "/owner/owner.md"
    yaml_list = common.find_all_test_case_by_search(test_case_definition_dir)
    dir_list = os.listdir(test_case_definition_dir)
    dir_name_lists = get_all_dir_names(dir_list, test_case_definition_dir)

    # prepare owner data, allow empty owner file
    owner = []
    if os.path.exists(owner_file):
        owner = get_owner_data(owner_file)

    name_dict = get_name_from_yaml(yaml_list, dir_name_lists, owner, test_case_definition_dir)
    for job_key in result_json_dict:
        result = result_json_dict[job_key]
        for item in result:
            if item.has_key('suite') and item['suite'] != 'lava':
                suit_name = item['suite'][2:]
                for key in name_dict.keys():
                    for sub_key in name_dict[key].keys():
                        for suite_key in name_dict[key][sub_key].keys():
                            if suite_key != "tester" and suite_key != "developer":
                                if suite_key == suit_name:
                                    name_dict[key][sub_key][suite_key][item["name"]] = item["result"]
    for job_key in result_json_dict:
        result = result_json_dict[job_key]
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

            result += "    [\"%s\",\"%s\",\"%s\",\"%s\",\"%.2f%%\",{\"data\": \"%s\", \"color\": \"%s\"},{\"data\": \"%s\", \"color\": \"%s\"},{\"data\": \"%s\", \"color\": \"%s\"}],\n" \
                      % ( sub_key,
                          name_dict[name_key][sub_key]["developer"],
                          name_dict[name_key][sub_key]["tester"],
                          str(name_dict[name_key][sub_key]["total"]),
                          100.0 * name_dict[name_key][sub_key]["pass"] / name_dict[name_key][sub_key]["total"] if name_dict[name_key][sub_key]["total"] == 0 else 0.0,
                          str(name_dict[name_key][sub_key]["pass"]), PASS_COLOR,
                          str(name_dict[name_key][sub_key]["fail"]), FAIL_COLOR,
                          str(name_dict[name_key][sub_key]["total"] - name_dict[name_key][sub_key]["fail"] -
                              name_dict[name_key][sub_key]["pass"]), BLOCK_COLOR)
        result = result.rstrip(",\n")
        result += "],\n"
    if len(result) > 0:
        result = result.rstrip(",\n")
    return result


def main2():
    # ./module-table-analysis.py -f /home/qinshulei/projects/huawei/githubs/test_result_dict.json -t /home/qinshulei/projects/huawei/githubs/test-definitions
    # generate_module_result(result_json_dict, test_dir)
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
    result_json_dict = utils.load_json(result_file)
    print generate_module_result(result_json_dict, test_dir)

def main(args):
    config = configuration.get_config(args)

    global TEST_CASE_DEFINITION_DIR
    TEST_CASE_DEFINITION_DIR = config.get("testDir")
    distro = config.get("distro")

    if config.get("boot"):
        boot_report(config)
        generate_current_test_report()
        generate_email_test_report(distro)
        generate_scope_test_report(TEST_CASE_DEFINITION_DIR)
        generate_history_test_report()

    exit(0)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--boot", help="creates a kernel-ci boot report from a given json file")
    parser.add_argument("--lab", help="lab id")
    parser.add_argument("--testDir", required=True, help="specific test case dir")
    parser.add_argument("--distro", choices=['Ubuntu', 'Debian', 'CentOS',
                                             'OpenSuse', 'Fedora'],
                        help="distro for sata deploying")
    args = vars(parser.parse_args())
    main(args)
