#!/usr/bin/python
# -*- coding=utf-8 -*-
#
# Author by : qinsl0106@thundersoft.com

import json
import sys
import os
import argparse

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
                    if item.has_key('link') and item.has_key('color'):
                        row_str += ('<td style="border: solid 1px black;"> <a href="' + item['link'] + '" style="color:' +item['color']+ '">' +
                            item['data'] + '</a></td>\n')
                    elif item.has_key('link'):
                        row_str += ('<td style="border: solid 1px black;"> <a href="' + item[
                            'link'] + '">' + item['data'] + '</a></td>\n')
                    elif item.has_key('color'):
                        row_str += ('<td style="border: solid 1px black;"> <font color="' + item[
                            'color'] + '">' + item['data'] + '</font></td>\n')
                else:
                    row_str += ('<td style="border: solid 1px black;">' + str(
                        item) + '</td>\n')
            row_str += '</tr>\n<tr>\n'
        else:
            rowspan = row_span_arr.pop(0)
            if isinstance(rows, dict):
                if rows.has_key('link') and rows.has_key('color'):
                    row_str += '\n<td rowspan=%s style="border: solid 1px black;">' % rowspan + '<a href="' + rows['link'] + '" style="color:' +rows['color']+ '">' +rows['data'] + '</a></td>\n'
                elif rows.has_key('link'):
                    row_str += ('<td rowspan=%s style="border: solid 1px black;"> <a href="'%rowspan + rows[
                        'link'] + '">' + rows['data'] + '</a></td>\n')
                elif rows.has_key('color'):
                    row_str += ('<td rowspan=%s style="border: solid 1px black;"> <font color="'%rowspan + rows[
                        'color'] + '">' + rows['data'] + '</font></td>\n')
            else:
                row_str += '\n<td rowspan=%s style="border: solid 1px black;">' % rowspan + str(
                    rows) + '</td>\n'

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
                col_str += '<td colspan=%s style="border: solid 1px black;">%s</td>\n' % (
                    len(column[index + 1]), column[index])
            else:
                col_str += '<td rowspan=2 style="border: solid 1px black;"> %s</td>\n' % \
                           column[index]

        col_str += '</tr>\n<tr>'
        for index in tmp:
            for item in column[index]:
                col_str += '<td style="border: solid 1px black;">%s</td>\n' % item
        col_str += '</tr>'
        return col_str
    else:
        col_str = ''
        col_str += '<tr style="text-align: center;justify-content: center">\n'
        for item in column:
            col_str += '<td style="border: solid 1px black;">%s</td>\n' % item
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
    print '<table cellspacing="0px" style="border: solid 1px black;">\n'+ column + '\n' + content + '</table>'


if __name__ == '__main__':
    main()
