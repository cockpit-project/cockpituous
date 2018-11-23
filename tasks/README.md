# Cockpit Continuous Integration

This is the staging container and configuration for the Cockpit
integration tests. This documentation is for deployment on Fedora 22+
or RHEL 7+.

Use the following commands to run the tasks container as a one off:

    $ sudo yum -y install docker atomic oci-kvm-hook
    $ sudo systemctl start docker
    $ sudo atomic run cockpit/tasks

You can run the tests in the resulting container shell like this.
Or see tests/HACKING in the cockpit repo for more info.

   $ test/verify/run-tests --install

The container has optional mounts:

 * ```/secrets```: A directory containing at least the following files
   * ```ssh-config```: SSH configuration file containing a 'sink' host
   * ```github-token```: A file containing a GitHub token to post results
   * ```image-stores```: Non default locations to try downloading images from
   * ```rhel-login```: Red Hat subscription credential login (optional)
   * ```rhel-password```: Red Hat subscription credential password (optional)
 * ```/cache```: A directory for reusable cached data such as downloaded image files

The mounts normally default to ```/var/lib/cockpit-tasks/secrets``` and
```/var/cache/cockpit-tasks``` on the host.

# Deploying on a host

For testing machines that publish back results create a file called
```/var/lib/cockpit-tasks/secrets/ssh-config``` as follows, and place ```id_rsa```
```id_rsa.pub``` ```authorized_keys``` and a ```github-token``` in the same directory.

    UserKnownHostsFile /secrets/authorized_keys
    Host sink
        HostName fedorapeople.org
        IdentityFile /secrets/id_rsa
        User cockpit

To transfer secrets from one host to another, you would do something like:

    $ SRC=user@source.example.com
    $ DEST=user@source.example.com
    $ ssh $SRC sudo tar -czf - /var/lib/cockpit-tasks/secrets/ | ssh $DEST sudo tar -C / -xzvf -

Make sure docker and atomic are installed and running:

    $ sudo systemctl enable docker
    $ sudo atomic install cockpit/tasks

You may want to customize things like the operating system to test or number of jobs:

    $ sudo mkdir -p /etc/systemd/system/cockpit-tasks.service.d
    $ sudo sh -c 'printf "[Service]\nEnvironment=TEST_JOBS=8\n" > /etc/systemd/system/cockpit-tasks.service.d/jobs.conf'
    $ sudo sh -c 'printf "[Service]\nEnvironment=TEST_CACHE=/mnt/nfs/share/cache\n" > /etc/systemd/system/cockpit-tasks.service.d/cache.conf'
    $ sudo systemctl daemon-reload

And now you can start the service:

    $ sudo systemctl start cockpit-tasks
    $ sudo systemctl enable cockpit-tasks

## Troubleshooting

Some helpful commands:

    # journalctl -fu cockpit-tasks
    # systemctl stop cockpit-tasks

## Updates

To update, just pull the new container and restart the cockpit-tasks service.
It will restart automatically when it finds a pause in the verification work.

    # docker pull cockpit/tasks

## Deploying on Openshift

The testing machines can run on Openshift cluster(s).

Create a service account for use by the testing machines. Make sure to have the
```oci-kvm-hook``` package installed on all nodes.  This is because of the requirement
to access ```/dev/kvm```. Further work is necessary to remove this requirement.

    $ oc create -f tasks/cockpituous-account.json
    $ oc adm policy add-scc-to-user anyuid -z cockpituous
    $ oc adm policy add-scc-to-user hostmount-anyuid -z cockpituous

Now create all the remaining kubernetes objects. The secrets are created from
the ```/var/lib/cockpit-tasks/secrets``` directory as described above. For the
webhook secrets a github token `~/.config/github-webhook-token` should be
present.

    $ sudo make tasks-secrets | oc create -f -
    $ oc create -f tasks/cockpit-tasks.json

## Troubleshooting

Some helpful commands:

    $ oc describe rc
    $ oc describe pods
    $ oc log -f cockpit-tasks-xxxx

The tests need ```/dev/kvm``` to be accessible to non-root users on each node:

    $ sudo modprobe kvm
    $ printf 'kvm\n' | sudo tee /etc/modules-load.d/kvm.conf
    $ sudo chmod 666 /dev/kvm
    $ printf 'KERNEL=="kvm", GROUP="kvm", MODE="0666"\n' | sudo tee /etc/udev/rules.d/80-kvm.rules

Some of the older tests need ip6_tables to be loaded:

    $ sudo modprobe ip6_tables
    $ printf 'ip6_tables\n' | sudo tee /etc/modules-load.d/ip6_tables.conf

Some tests need nested virtualization enabled:

    $ sudo -s
    # echo "options kvm-intel nested=1" > /etc/modprobe.d/kvm-intel.conf
    # echo "options kvm-amd nested=1" > /etc/modprobe.d/kvm-amd.conf
    # ( rmmod kvm-intel && modprobe kvm-intel ) || ( rmmod kvm-amd && modprobe kvm-amd )

SELinux needs to know about the caching directories:

    # chcon -Rt svirt_sandbox_file_t /var/cache/cockpit-tasks/

Service affinity currently wants all the cockpit-tasks pods to be in the same region.
If you have your own cluster make sure all the nodes are in the same region:

    $ oc patch node node.example.com -p '{"metadata":{"labels": {"region": "infra"}}}'

## Scaling

We can scale the number of testing machines in the openshift cluster with this
command:

    $ oc scale rc cockpit-tasks --replicas=3

## Let GitHub webhook trigger actions

The intention is that the webhook pod automatically starts a release runner
whenever a new release tag gets pushed to a project. This can be done with a
[GitHub webhook](https://developer.github.com/webhooks/).

Add a webhook to your GitHub project on the Settings → Webhooks page of your project:

 * Set a Payload URL like

       http://webhook-cockpit.apps.ci.centos.org/tools/cockpituous

   using the URL of the deployed route, and the path to the release script of
   the corresponding project's git tree (the git repository URL will be taken
   from the POST data that GitHub sends).

 * Use the same secret as in `~/.config/github-webhook-token` above.

 * Change the Content Type to `application/json`.

 * Select "Let me select individual events" and let the hook run on "Branch or
   tag creation", and nothing else.
