#!/usr/bin/python
# -*- coding=utf-8 -*-
#
# Author by : qinsl0106@thundersoft.com
# generate html table

import json
import sys
import os
import argparse

table_style = 'style=""'
tr_th_style = 'style="text-align: center;justify-content: center;background-color: #b9bbc0;"'
tr_style = 'style="text-align: center;justify-content: center;"'
th_style = 'style=""'
td_style = 'style=""'


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


def load_json(file_name):
    with open(file_name) as f:
        data = json.load(f, object_hook=_decode_dict)
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
                    row_str += ('<td ' + td_style + '>' + str(
                        item) + '</td>\n')
            row_str += '</tr>\n<tr ' + tr_style + '>\n'
        else:
            rowspan = row_span_arr.pop(0)
            if isinstance(rows, dict):
                row_str += extract_dict(rows, rowspan)
            else:
                row_str += '\n<td rowspan=%s ' % rowspan + td_style + '>' \
                    + str(rows) + '</td>\n'

    return row_str


def extract_dict(data, rowspan=1):
    row_str = ''
    if data.has_key('link') and data.has_key('color'):
        row_str += ('<td rowspan=%s '%rowspan + td_style + '> <a href="' \
                    + data['link'] + '" style="color:' + data['color'] + '">' \
                    + data['data'] + '</a></td>\n')
    elif data.has_key('link'):
        row_str += ('<td rowspan=%s '%rowspan + td_style + '>  <a href="' \
                    + data['link'] + '">' + data['data'] + '</a></td>\n')
    elif data.has_key('color'):
        row_str += ('<td rowspan=%s '%rowspan + td_style + '>  <font color="' \
                    + data['color'] + '">' + data['data'] + '</font></td>\n')
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
        col_str += '<tr ' + tr_th_style + '>\n'
        for index in range(len(column)):
            if index in tmp:
                continue
            if index in tmp2:
                col_str += '<th colspan=%s ' % len(column[index + 1]) + th_style + '>%s</th>\n' % (
                   column[index])
            else:
                col_str += '<th rowspan=2 ' + th_style + '> %s</th>\n' % column[index]

        col_str += '</tr>\n<tr ' + tr_th_style + '>'
        for index in tmp:
            for item in column[index]:
                col_str += '<th ' + th_style + '>%s</th>\n' % item
        col_str += '</tr>'
        return col_str
    else:
        col_str = ''
        col_str += '<tr ' + tr_th_style + '>\n'
        for item in column:
            col_str += '<th ' + th_style + '>%s</th>\n' % item
        col_str += '</tr>'
        return col_str


def main():
    # get args
    parser = argparse.ArgumentParser(prog='PROG')
    parser.add_argument('-f', '--file', required=True,
                        help='The data file path to load.')
    parser.add_argument('-o', '--output_file', help='allow output the result to a file')
    args = parser.parse_args()

    # load data
    data = load_json(args.file)

    # process
    column_temp = data['Column']
    rows_temp = data['Row']

    row_index = []
    row_span_arr = get_rowspan(rows_temp, row_index)

    temp_rows_data = get_rows(rows_temp, row_span_arr, '').rstrip("\n")
    dumy_str = '<tr ' + tr_style + '>'
    if temp_rows_data.endswith(dumy_str):
        temp_rows_data = temp_rows_data[:-len(dumy_str)]
    content = "<tr " + tr_style + ">\n" + temp_rows_data

    column = get_col(column_temp)

    result = '<table cellspacing="0px" cellpadding="5px" border="1" ' + table_style + '>' \
                                  + column \
                                  + content \
                                  + '</table>'

    # if don't have output_file ,print to console
    if args.output_file:
        with open('test.txt', 'w') as f:
            f.write(result)
    else:
        print result

if __name__ == '__main__':
    main()
