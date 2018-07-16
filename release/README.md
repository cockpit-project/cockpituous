# Release Scripts

The various release scripts are present in this directory. They are mostly
meant to be reusable in standalone fashion, with as little logical input
and interdependency as possible.

Some notable scripts:

 * release-source: Builds a tarball and patches from a git repository
 * release-srpm: Builds a source rpm from a tarball, patches and spec file

The scripts can be run by the release-runner script in such a way that
they all prepare their steps, and then commit them after everything has
been prepared.

## Spec file requirements

For a spec file to work with the scripts, it should be setup like this:

    Version: 0

And not have any content after the following line:

    %changelog

## Preparing secrets

Setup a 'cockpit' user:

    # groupadd -g 1111 -r cockpit && useradd -r -g cockpit -u 1111 cockpit
    # mkdir -p /home/cockpit/.ssh /home/cockpit/.config /home/cockpit/release
    # chown cockpit:cockpit /home/cockpit

Fill in the following files with valid credentials able to post logs to sink and
update github status:

    /home/cockpit/.ssh/id_rsa
    /home/cockpit/.ssh/id_rsa.pub
    /home/cockpit/.ssh/known_hosts
    /home/cockpit/.config/bodhi-user
    /home/cockpit/.config/copr
    /home/cockpit/.config/github-token
    /home/cockpit/.config/github-whitelist
    /home/cockpit/.fedora-password
    /home/cockpit/.fedora.cert
    /home/cockpit/.fedora-server-ca.cert
    /home/cockpit/.gitconfig
    /home/cockpit/.gnupg

## Deploying on OpenShift

On some host `$SECRETHOST`, set up all necessary credentials as above, plus an
extra `~/.config/github-webhook-token` with a shared secret.

Then build a Kubernetes secret volume definition on that host, copy that to a
machine that administers your OpenShift cluster, and deploy that secret volume:

    ssh $SECRETHOST release/build-secrets | oc create -f -

Then deploy the other objects:

    oc create -f release/cockpit-release.yaml

This will create a POD that runs a simple HTTP server that acts as a
[GitHub webhook](https://developer.github.com/webhooks/). Set this up as a
webhook in GitHub, using an URL like

   http://release-cockpit.apps.ci.centos.org/bots/major-cockpit-release

using the path to the release script of the corresponding project's git tree
(the git repository URL will be taken from the POST data that GitHub sends).
Use the same secret as in `~/.config/github-webhook-token` above. Make sure to
change the Content Type to `application/json`.

To remove the deployment:

    oc delete -f release/cockpit-release.yaml
    oc delete secrets cockpit-release-secrets

## Manual operation and Troubleshooting

In cases where the Kubernetes/OpenShift deployment is not available, the
release container can also be started manually, on a host which has the above
secrets for user `cockpit`. A Cockpit release can be run with

    sudo make release-cockpit

For releasing a different project or manually running the release script of
cockpit (or possibly parts of it), you can get an interactive shell to a
release container with

    sudo make release-shell

Note that both of these will publish logs to fedorapeople.org by default. If
you want to disable this, or publish somewhere else, unset or change the
`$TEST_PUBLISH` environment variable instead.
