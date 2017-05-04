# Cockpit Continuous Integration

This is the staging container and configuration for the Cockpit
integration tests. This documentation is for deployment on Fedora 22+
or RHEL 7+.

Use the following commands to run the tests container as a one off:

    $ sudo yum -y install docker atomic
    $ sudo systemctl start docker
    $ sudo atomic run cockpit/tests

You can run the tests in the resulting container shell like this.
Or see tests/HACKING in the cockpit repo for more info.

   $ test/verify/run-tests --install

The container has optional mounts:

 * ```/secrets```: A directory containing at least the following files
   * ```ssh-config```: SSH configuration file
   * ```github-token```: A file containing a GitHub token to post results
 * ```/images```: A volume to store downloaded image files

The mounts normally default to ```/var/lib/cockpit-tests/secrets``` and
```/var/lib/cockpit-tests/images``` on the host.

# Deploying on a host

For testing machines that publish back results create a file called
```/var/lib/cockpit-tests/secrets/ssh-config``` as follows, and place ```id_rsa```
```id_rsa.pub``` ```authorized_keys``` and a ```github-token``` in the same directory.

    UserKnownHostsFile /secrets/authorized_keys
    Host fedorapeople.org
        IdentityFile /secrets/id_rsa
        User cockpit

Make sure docker and atomic are installed and running:

    $ sudo systemctl enable docker
    $ sudo atomic install cockpit/tests

You may want to customize things like the operating system to test or number of jobs:

    $ sudo mkdir -p /etc/systemd/system/cockpit-tests.service.d
    $ sudo sh -c 'printf "[Service]\nEnvironment=TEST_JOBS=8\n" > /etc/systemd/system/cockpit-tests.service.d/jobs.conf'
    $ sudo sh -c 'printf "[Service]\nEnvironment=VERIFY_IMAGES=/mnt/nfs/share/images\n" > /etc/systemd/system/cockpit-tests.service.d/images.conf'
    $ sudo systemctl daemon-reload

And now you can start the service:

    $ sudo systemctl start cockpit-tests
    $ sudo systemctl enable cockpit-tests

## Troubleshooting

Some helpful commands:

    # journalctl -fu cockpit-tests
    # systemctl stop cockpit-tests

## Updates

To update, just pull the new container and restart the cockpit-tests service.
It will restart automatically when it finds a pause in the verification work.

    # docker pull cockpit/tests

## Deploying on Openshift

The testing machines can run on Openshift cluster(s).

Create a service account for use by the testing machines.  Currently the privileged SCC
is used for scheduling the tests pod. This is because of the requirement to access
```/dev/kvm```. Further work is necessary to remove this requirement.

    $ oc create -f tests/cockpit-tester-account.json
    $ oc adm policy add-scc-to-user privileged -z tester

Now create all the remaining kubernetes objects. The secrets are created from the
```/var/lib/cockpit-tests/secrets``` directory as described above.

    $ sudo make tests-secrets | oc create -f -
    $ oc create -f tests/cockpit-tests.json

## Troubleshooting

Some helpful commands:

    $ oc describe rc
    $ oc describe pods
    $ oc log -f cockpit-tests-xxxx

## Scaling

We can scale the number of testing machines in the openshift cluster with this
command:

    $ oc scale rc cockpit-tests --replicas=3
