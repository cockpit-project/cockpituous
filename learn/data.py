#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# This file is part of Cockpit.
#
# Copyright (C) 2017 Slavek Kabrda
#
# Cockpit is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 2.1 of the License, or
# (at your option) any later version.
#
# Cockpit is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Cockpit; If not, see <http://www.gnu.org/licenses/>.

import gzip
import io
import json
import sys
import zlib

def failures(item):
    return item.get("status") == "failure"

def open_if(filename_or_fp, mode):
    if not isinstance(filename_or_fp, str):
        return filename_or_fp
    elif filename_or_fp.endswith(".gz"):
        fp = gzip.open(filename_or_fp, mode)
        if 'b' not in mode:
            fp = io.TextIOWrapper(fp, encoding='utf-8')
        return fp
    else:
        return open(filename_or_fp, mode)

def load(filename_or_fp, only=failures, limit=None, verbose=False):
    count = 0
    fp = open_if(filename_or_fp, 'r')
    try:
        while True:
            try:
                line = fp.readline()
            except (OSError, zlib.error) as ex:
                sys.stderr.write("tests-data: {0}\n".format(str(ex)))
                return
            if not line:
                return

            # Parse the line
            item = json.loads(line)

            # Now actually check for only values
            if only is not None and not only(item):
                continue

            yield item
            count += 1
            if verbose and count % 1000 == 0:
                sys.stderr.write("{0}: Items loaded\r".format(count))
            if limit is not None and count == limit:
                return
    finally:
        if verbose and count > 0:
            sys.stderr.write("{0}: Items loaded\n".format(count))
        fp.close()

def write(filename_or_fp, items, verbose=False):
    count = 0
    fp = open_if(filename_or_fp, 'w')
    try:
        for item in items:
            line = json.dumps(item) + "\n"
            fp.write(line)

            count += 1
            if verbose and count % 1000 == 0:
                sys.stderr.write("{0}: Items written\r".format(count))
    finally:
        if verbose and count > 0:
            sys.stderr.write("{0}: Items written\n".format(count))
        fp.close()
