#!/bin/sh
# clean up obsolete logs on our sink

set -ec
cd /srv/groups/cockpit/logs

# remove all logs older than two months
# keep logs for external projects for now, until we get them into machine learning
# ironically, the external projects have "-cockpit-" in the name (from a test
# like cockpit/rhel-7-6/chrome@weldr/welder-web), while cockpit's own tests are
# called "verify", "selenium", and "container"; this also catches logs from
# image rebuilds, test learning, etc.
find -mindepth 1 -maxdepth 1 -type d -mtime +60 ! -name '*-cockpit-*' -print -exec rm -rf {} \;

# remove auxiliary files (screenshots, core files etc.) older than one month;
# for machine learning we just need "log" and "status"
find -type f -mtime +30 ! -name log ! -name log.html ! -name status -print -delete

# core dumps and journals are really big, only keep the last two weeks
find \( -path '*.core*' -o -name '*-FAIL.log' \) -mtime +14 -delete
