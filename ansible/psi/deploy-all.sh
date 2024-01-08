#!/bin/sh
# This script also works if there are existing instances, they will be deleted first.
set -eu

# cd to ansible/
cd "$(dirname $(dirname $(realpath $0)))"

# number of instances; limited by quota
NUM=35

seq $NUM | parallel --line-buffer -j4 ansible-playbook -i inventory/ -e instance_name='rhos-01-{}' psi/launch-tasks.yml

ansible-playbook -i inventory/ psi/image-cache.yml
