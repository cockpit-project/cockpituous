# Cockpituous Project Release Automation

Cockpituous release aims to fully automate project releases to GitHub, Fedora,
Ubuntu, COPR, Docker Hub, and other places. The intention is that the *only*
manual step for releasing a project is to create a signed tag for the version
number:

    git tag -s 123

With the tag description being a list of highlights/changes in the new release
in this format:

    123

    - Add this cool new feature
    - Support Python 3
    - Fix wrong color on the bikeshed

Pushing the tag (`git push origin --tags`) triggers a set of release scripts
that do the rest.

## Release Scripts

The various release scripts are present in this directory. They are mostly
meant to be reusable in standalone fashion, with as little logical input
and interdependency as possible.

Some notable scripts:

 * release-source: Builds a tarball and patches from a git repository
 * release-srpm: Builds a source rpm from a tarball, patches and spec file,
   using the tag description as `%changelog`
 * release-github: Puts the tarball on the GitHub project releases page, using
   the tag description as release notes

These are used in project specific "delivery scripts", which lists which steps
should be taken to release a particular project, i. e. to which places (GitHub,
Fedora, COPR, Ubuntu PPA, etc.) the release should be done.

These delivery scripts are run by [release-runner](./release-runner) in such a
way that they all prepare their steps, and then commit them after everything
has been prepared. See the delivery scripts of
[cockpit](https://github.com/cockpit-project/cockpit/blob/master/tools/cockpituous-release)
and
[cockpit-composer](https://github.com/weldr/cockpit-composer/blob/master/utils/cockpituous-release)
as examples.

You can test your script locally (possibly in a
[cockpit/tests container](https://hub.docker.com/r/cockpit/tests/)) like
this:

 * Run `git clean -ffdx` to make sure you are testing a clean tree.

 * If you don't already have a release tag, create a temporary "fake" release
   with e. g.

       git tag -s 999 -m "$(printf '999\n\n- test release\n')"

 * Start the release runner:

       /path/to/cockpituous/release/release-runner -t 999 -n ./cockpituous-release

   where `./cockpituous-release` is the path to the release script within your
   project. The `-n` will do a "dry run" where the "commit" parts of the script
   (i. e. "really" release to GitHub, COPR, bodhi, etc.) are skipped, but the
   "prepare" parts (`make dist`, koji scratch build, etc.) are run.

 * Finally, don't forget to  delete your fake release tag, if you created one
   above:

       git tag -d 999

## Spec file requirements

For a spec file to work with `release-srpm`, it should have `Version: 0`.
If your build system already puts the target release version into `Version:`,
call `release-srpm` with the `-V` option instead, otherwise it will assume that
this version was already released in a previous srpm and bump the `Release:`.

The spec file must not have any content after `%changelog`. It will generate a
changelog from the git tag description.

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

On some host `$SECRETHOST`, set up all necessary credentials as above.

Then build a Kubernetes secret volume definition on that host, copy that to a
machine that administers your OpenShift cluster, and deploy that secret volume:

    ssh $SECRETHOST release/build-secrets | oc create -f -

Now everything is in place to spawn release runner pods.

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
`$RELEASE_SINK` environment variable instead.
