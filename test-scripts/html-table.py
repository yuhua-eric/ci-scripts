#!/usr/bin/python
# -*- coding=utf-8 -*-
#
# Author by : qinsl0106@thundersoft.com
# generate html table

import json
import sys
import os
import argparse

style = 'style="border: solid 1px black;"'


def load_json(file_name):
    with open(file_name) as f:
        data = json.load(f)
        return data


def is_nested_arr(arr):
    for item in arr:
        if isinstance(item, list):
            return True
    return False


def recursive_len(item):
    if is_nested_arr(item):
        return sum(recursive_len(subitem) for subitem in item if isinstance(subitem, list))
    else:
        return 1


def get_rowspan(rows_temp, row_index):
    if is_nested_arr(rows_temp):
        row_index.append(recursive_len(rows_temp))
        for item in rows_temp:
            get_rowspan(item, row_index)
    return row_index[1:]


def get_rows(rows, row_span_arr, row_str):
    # table with row span
    if is_nested_arr(rows):
        for item in rows:
            row_str += get_rows(item, row_span_arr, '')
    else:
        # simple table without row span
        if isinstance(rows, list):
            for item in rows:
                # has dict element, which means has link or color
                if isinstance(item, dict):
                    row_str += extract_dict(item)
                else:
                    row_str += ('<td ' + style + '>' + str(
                        item) + '</td>\n')
            row_str += '</tr>\n<tr>\n'
        else:
            rowspan = row_span_arr.pop(0)
            if isinstance(rows, dict):
                row_str += extract_dict(rows, rowspan)
            else:
                row_str += '\n<td rowspan=%s '% rowspan + style + '>' + str(
                    rows) + '</td>\n'

    return row_str


def extract_dict(data, rowspan=1):
    row_str = ''
    if data.has_key('link') and data.has_key('color'):
        row_str += ('<td rowspan=%s '%rowspan + style + '> <a href="' + data['link'] + '" style="color:' + data[
            'color'] + '">' +
                    data['data'] + '</a></td>\n')
    elif data.has_key('link'):
        row_str += ('<td rowspan=%s '%rowspan + style + '>  <a href="' + data[
            'link'] + '">' + data['data'] + '</a></td>\n')
    elif data.has_key('color'):
        row_str += ('<td rowspan=%s '%rowspan + style + '>  <font color="' + data[
            'color'] + '">' + data['data'] + '</font></td>\n')
    return row_str


def get_col(column):
    has_list = False
    for item in column:
        if isinstance(item, list):
            has_list = True
            break
    if has_list:
        col_str = ''
        tmp = []
        for item in column:
            if isinstance(item, list):
                tmp.append(column.index(item))
        tmp2 = [(x - 1) for x in tmp]
        col_str += '<tr style="text-align: center;justify-content: center">\n'
        for index in range(len(column)):
            if index in tmp:
                continue
            if index in tmp2:
                col_str += '<td colspan=%s '%len(column[index + 1]) + style + '>%s</td>\n' % (
                   column[index])
            else:
                col_str += '<td rowspan=2 ' + style + '> %s</td>\n' % column[index]

        col_str += '</tr>\n<tr>'
        for index in tmp:
            for item in column[index]:
                col_str += '<td '+ style + '>%s</td>\n' % item
        col_str += '</tr>'
        return col_str
    else:
        col_str = ''
        col_str += '<tr style="text-align: center;justify-content: center">\n'
        for item in column:
            col_str += '<td ' + style + '>%s</td>\n' % item
        col_str += '</tr>'
        return col_str


def main():
    # get args
    parser = argparse.ArgumentParser(prog='PROG')
    parser.add_argument('-f', '--file', required=True, help='The data file path to load.')
    args = parser.parse_args()

    # load data
    data = load_json(args.file)

    # process
    column_temp = data['Column']
    rows_temp = data['Row']

    row_index = []
    row_span_arr = get_rowspan(rows_temp, row_index)

    content = "<tr>\n" + get_rows(rows_temp, row_span_arr, '')[:-5]
    column = get_col(column_temp)
    print '<table cellspacing="0px" '+ style + '>\n'+ column + '\n' + content + '</table>'

    # for test use
    # x = '<table cellspacing="0px" '+ style + '>\n'+ column + '\n' + content + '</table>'
    # with open('test.txt', 'w') as f:
    #     f.write(x)

if __name__ == '__main__':
    main()
