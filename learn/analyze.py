#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# This file is part of Cockpit.
#
# Copyright (C) 2017 Stef Walter
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

import os

import data

class Group(dict):
    total = 0

    def count(self, field, value, factor=1):
        def add(value):
            values = self.get(field)
            if values is None:
                self[field] = values = { }
            count = values.get(value, 0)
            values[value] = count + factor
        if isinstance(value, (list, tuple)):
            for val in value:
                add(value)
        elif not isinstance(value, dict):
            add(value)

    def bound(self, field, value, factor=1):
        def add(value):
            values = self.get(field)
            if values is None:
                self[field] = values = [None, None]
            if values[0] is None or value <= values[0]:
                values[0] = value
            if values[1] is None or value >= values[1]:
                values[1] = value
        if isinstance(value, (list, tuple)):
            for val in value:
                add(value)
        elif value is not None and not isinstance(value, dict):
            add(value)

    def finalize(self):
        for field, values in self.items():
            if isinstance(values, dict):
                self[field] = [ ]
                for value, count in values.items():
                    self[field].append((value, count))
                self[field].sort(key=lambda x: x[1], reverse=True)

class Groups():
    def __init__(self, name):
        self.name = name
        self.data = { }

    def count(self, key, item, field):
        group = self.data.get(key)
        if group is None:
            self.data[key] = group = Group()
        group.count(field, item.get(field))

    def bound(self, key, item, field):
        group = self.data.get(key)
        if group is None:
            self.data[key] = group = Group()
        group.bound(field, item.get(field))

    def dump(self, directory):
        if not os.path.exists(directory):
            os.mkdir(directory)

        for key, group in self.data.items():
            group.finalize()

        path = os.path.join(directory, "{0}.jsonl".format(self.name))
        data.write(path, self.data.values())
