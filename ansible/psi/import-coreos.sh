#!/bin/sh
# Requirements: sudo dnf install python3-openstackclient jq qemu-img

set -eu

URL=$(curl --silent --show-error https://builds.coreos.fedoraproject.org/streams/stable.json | jq -r '.architectures.x86_64.artifacts.openstack.formats["qcow2.xz"].disk.location')

curl -L -O "$URL"
xz -d fedora-coreos-*.qcow2.xz
# convert to raw: faster CoW and more efficient ceph usage
qemu-img convert fedora-coreos-*.qcow2 fedora-coreos.raw
rm fedora-coreos-*.qcow2
openstack --os-cloud rhos-01 image create --disk-format raw --container-format bare --file fedora-coreos.raw "Fedora-CoreOS"
rm fedora-coreos.raw
