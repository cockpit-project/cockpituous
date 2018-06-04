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

# Spec file requirements

For a spec file to work with the scripts, it should be setup like this:

    Version: 0

And not have any content after the following line:

    %changelog

# Cockpit Release Runner

This is the container for the Cockpit release runner. It normally gets
activated through a HTTP request: <http://host:8090/cockpit>. The "/cockpit"
path specifies the systemd service name to start (<name>-release.service).

## How to deploy

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

Install the systemd services:

    # git clone https://github.com/cockpit-project/cockpituous.git /tmp/cockpituous
    # make -C /tmp/cockpituous release-install

Add a webhook to your GitHub project that calls http://host:8090/cockpit on
"create" events (and nothing else!); set this in "Let me select individual events".

# Troubleshooting

Follow the logs of a running release:

    # journalctl -fu cockpit-release

Start the container manually (without a webhook):

    # systemctl start cockpit-release

