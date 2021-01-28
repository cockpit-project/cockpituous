# Cockpit image server

This is an image store for hosting VMs for Cockpit integration tests.

# Deploying on a host

Secrets need to be set up in the same way as for the [tasks container](../tasks/README.md). This container particularly needs the [CA](../tasks/credentials/generate-ca.sh) and [server SSL certificates](./generate-image-certs.sh) and the `htpasswd` file for authenticating users that are allowed to upload.

    $ sudo docker pull quay.io/cockpit/images
    $ sudo atomic install quay.io/cockpit/images

Or, if the `atomic` command is not available, run

    $ sudo docker inspect --format '{{ index .Config.Labels "INSTALL"}}' quay.io/cockpit/images  | sed 's_IMAGE_cockpit/images_'

and execute that command.

    $ sudo systemctl start cockpit-images

# Deploying on OpenShift

Again, secrets need to be set up in the same way as for the OpenShift
deployment for [tasks](../tasks/README.md), in particular the
`cockpit-tasks-secrets` secret volume.

This needs a large persistent volume to hold the images. Create a claim for it
with

    oc create -f images/images-claim.yaml

then wait until it gets provisioned, and create the remaining objects with

    oc create -f images/cockpit-images.yaml
