#!/usr/bin/python3
# -*- coding: utf-8 -*-

# This file is part of Cockpit.
#
# Copyright (C) 2015 Red Hat, Inc.
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

# Shared GitHub code. When run as a script, we print out info about
# our GitHub interacition.

import errno
import http.client
import json
import os
import re
import socket
import sys
import time
import urllib.parse

import cache

__all__ = (
    'GitHub',
)

TOKEN = "~/.config/github-token"

class Logger(object):
    def __init__(self, directory):
        hostname = socket.gethostname().split(".")[0]
        month = time.strftime("%Y%m")
        self.path = os.path.join(directory, "{0}-{1}.log".format(hostname, month))

        if not os.path.exists(directory):
            os.makedirs(directory)

    # Yes, we open the file each time
    def write(self, value):
        with open(self.path, 'a') as f:
            f.write(value)

# Parse a dictionary of links from a Link header RFC 5988
def links(value, key='rel'):
    result = { }
    replace_chars = " '\""
    for val in re.split(", *<", value):
        try:
            url, params = val.split(";", 1)
        except ValueError:
            url, params = val, ''
        link = url.strip("<> '\"")
        for param in params.split(";"):
            try:
                k, v = param.split("=")
            except ValueError:
                break
            if k.strip(replace_chars) == key:
                result[v.strip(replace_chars)] = link
    return result

class GitHub(object):
    def __init__(self, base=None, cacher=None, repo=None):
        if base is None:
            if repo is None:
                repo = os.environ.get("GITHUB_BASE", "cockpit-project/cockpit")
            netloc = os.environ.get("GITHUB_API", "https://api.github.com")
            base = "{0}/repos/{1}/".format(netloc, repo)
        if not base.endswith("/"):
            base = base + "/"
        self.url = urllib.parse.urlparse(base)
        self.conn = None
        self.token = None
        self.debug = False
        try:
            gt = open(os.path.expanduser(TOKEN), "r")
            self.token = gt.read().strip()
            gt.close()
        except IOError as exc:
            if exc.errno == errno.ENOENT:
                pass
            else:
                raise
        self.available = self.token and True or False

        # The cache directory is $TEST_DATA/github ~/.cache/github
        if not cacher:
            data = os.environ.get("TEST_DATA",  os.path.expanduser("~/.cache"))
            cacher = cache.Cache(os.path.join(data, "github"))
        self.cache = cacher

        # Create a log for debugging our GitHub access
        self.log = Logger(self.cache.directory)
        self.log.write("")

    def qualify(self, resource):
        return urllib.parse.urljoin(self.url.path, resource)

    def request(self, method, resource, data="", headers=None):
        resource = self.qualify(resource)
        if headers is None:
            headers = { }
        headers["User-Agent"] = "Cockpit Tests"
        if self.token:
            headers["Authorization"] = "token " + self.token
        connected = False
        while not connected:
            if not self.conn:
                if self.url.scheme == 'http':
                    self.conn = http.client.HTTPConnection(self.url.netloc)
                else:
                    self.conn = http.client.HTTPSConnection(self.url.netloc)
                connected = True
            self.conn.set_debuglevel(self.debug and 1 or 0)
            try:
                self.conn.request(method, resource, data, headers)
                response = self.conn.getresponse()
                break
            # This happens when GitHub disconnects in python3
            except ConnectionResetError:
                if connected:
                    raise
                self.conn = None
            # This happens when GitHub disconnects a keep-alive connection
            except http.client.BadStatusLine:
                if connected:
                    raise
                self.conn = None
            # This happens when TLS is the source of a disconnection
            except socket.error as ex:
                if connected or ex.errno != errno.EPIPE:
                    raise
                self.conn = None
        heads = { }
        for (header, value) in response.getheaders():
            heads[header.lower()] = value
        self.log.write('{0} - - [{1}] "{2} {3} HTTP/1.1" {4} -\n'.format(
            self.url.netloc,
            time.asctime(),
            method,
            resource,
            response.status
        ))
        return {
            "status": response.status,
            "reason": response.reason,
            "headers": heads,
            "data": response.read().decode('utf-8')
        }

    def _get(self, resource, accept=[], verbose=True):
        headers = { }
        qualified = self.qualify(resource)
        cached = self.cache.read(qualified)
        if cached:
            if self.cache.current(qualified):
                return cached
            etag = cached['headers'].get("etag", None)
            modified = cached['headers'].get("last-modified", None)
            if etag:
                headers['If-None-Match'] = etag
            elif modified:
                headers['If-Modified-Since'] = modified
        response = self.request("GET", resource, "", headers)
        status = response['status']
        if status == 404:
            return response
        elif cached and status == 304: # Not modified
            self.cache.write(qualified, cached)
            return cached
        elif (status < 200 or status >= 300) and status not in accept:
            if verbose:
                sys.stderr.write("{0}\n{1}\n".format(resource, response['data']))
            return response
        else:
            self.cache.write(qualified, response)
            return response

    def _parse(self, response, accept=[]):
        status = response['status']
        if status == 404:
            return None
        elif (status < 200 or status >= 300) and status not in accept:
            raise RuntimeError("GitHub API problem: {0}".format(response['reason'] or response['status']))
        else:
            return json.loads(response['data'] or "null")

    def get(self, resource, accept=[], verbose=True):
        return self._parse(self._get(resource, accept=accept, verbose=verbose), accept=accept)

    def post(self, resource, data, raw=False, accept=[]):
        response = self.request("POST", resource, json.dumps(data), { "Content-Type": "application/json" })
        status = response['status']
        if (status < 200 or status >= 300) and status not in accept:
            sys.stderr.write("{0}\n{1}\n".format(resource, response['data']))
            raise RuntimeError("GitHub API problem: {0}".format(response['reason'] or status))
        self.cache.mark()
        return raw and response or json.loads(response['data'])

    def delete(self, resource, raw=False, accept=[]):
        response = self.request("DELETE", resource, "", { "Content-Type": "application/json" })
        status = response['status']
        if (status < 200 or status >= 300) and status not in accept:
            sys.stderr.write("{0}\n{1}\n".format(resource, response['data']))
            raise RuntimeError("GitHub API problem: {0}".format(response['reason'] or status))
        self.cache.mark()
        return raw and response or json.loads(response['data'])

    def patch(self, resource, data, raw=False, accept=[]):
        response = self.request("PATCH", resource, json.dumps(data), { "Content-Type": "application/json" })
        status = response['status']
        if (status < 200 or status >= 300) and status not in accept:
            sys.stderr.write("{0}\n{1}\n".format(resource, response['data']))
            raise RuntimeError("GitHub API problem: {0}".format(response['reason'] or status))
        self.cache.mark()
        return raw and response or json.loads(response['data'])

    def objects(self, path, filter=None):
        while path:
            response = self._get(path)
            link = response["headers"].get("link", "")
            next = links(link, key='rel').get("next")
            if next:
                url = urllib.parse.urlparse(next)
                path = url.path
                if url.params:
                    path += ';' + url.params
                if url.query:
                    path += '?' + url.query
            else:
                path = None
            for obj in self._parse(response) or []:
                try:
                    if filter is not None:
                        if not filter(obj):
                            continue
                except StopIteration:
                    return
                yield obj
