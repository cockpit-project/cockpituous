# This file is part of Cockpit.
#
# Copyright (C) 2020 Red Hat, Inc.
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

import logging
import os


__all__ = (
    'github_webhook_token',
)

# for amqp certs on aws:
# store in env
# write them out to /tmp/certs
# load them in distributed_queue

# for the webhook token


def github_webhook_token():
    token = os.getenv("GITHUB_WEBHOOK_TOKEN")
    if token:
        logging.info("TOKEN FOUND")
        return token.encode('utf-8')
    logging.info("TOKEN NOT FOUND")

    # keyfile = os.path.expanduser('~/.config/github-webhook-token')
    # try:
    #     with open(keyfile, 'rb') as f:
    #         token = f.read().strip()
    # except IOError as e:
    #         logging.error('Failed to load GitHub key: %s', e)
    # return token
