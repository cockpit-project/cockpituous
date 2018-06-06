# Cockpit image server

This is an image store for hosting VMs for Cockpit integration tests.

# Deploying on a host

Secrets need to be set up in the same way as for the
[tests container](../tests/README.md). This container particularly needs the CA
and server SSL certificates and the `htpasswd` file for authenticating users
that are allowed to upload.

    $ sudo docker pull cockpit/images
    $ sudo atomic install cockpit/tests
    $ sudo systemctl start cockpit-tests

# Deploying on OpenShift

Again, secrets need to be set up in the same way as for the OpenShift
deployment for [tests](../tests/README.md), in particular the
`cockpit-tests-secrets` secret volume.

This needs a large persistent volume to hold the images. Create a claim for it
with

    oc create -f images/images-claim.yaml

then wait until it gets provisioned, and create the remaining objects with

    oc create -f images/cockpit-images.yaml
