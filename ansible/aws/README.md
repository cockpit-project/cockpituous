Resources for setting up CI in AWS
==================================

AWS user management console
---------------------------

 * Sign in [with your kerberos ticket](https://auth.redhat.com/auth/realms/EmployeeIDP/protocol/saml/clients/itaws); this needs to be set up first for new users, ask Miroslav Vadkerti about it
 * The [User management console](https://console.aws.amazon.com/iam/home?#/users) shows the available users and their Access Keys. The Cockpit team CI uses the [arr-cockpit](https://console.aws.amazon.com/iam/home?#/users/arr-cockpit) user for CI runtime, and the [arr-cockpit-bootstrap](https://us-east-1.console.aws.amazon.com/iam/home#/users/details/arr-cockpit-bootstrap?section=permissions) user for deploying the S3 buckets/credentials.

Contact Miroslav Vadkerti about maintaining these users, privileges, and access keys.

Credentials configuration
-------------------------
For interacting with AWS with these Ansible playbooks or with the [AWS CLI](https://docs.aws.amazon.com/cli/index.html), configure multiple profiles in `~/.config/aws/credentials`:

```ini
# arr-cockpit
[default]
aws_access_key_id = AKIA...arr-cockpit...
aws_secret_access_key = ...arr-cockpit-secret...

# arr-cockpit-bootstrap
[bootstrap]
aws_access_key_id = AKIA...arr-cockpit-bootstrap...
aws_secret_access_key = ...arr-cockpit-bootstrap-secret...
```

The `[default]` profile (arr-cockpit user) is for runtime operations: EC2 instances, S3 uploads.
The `[bootstrap]` profile (arr-cockpit-bootstrap user) is for infrastructure setup: creating/configuring S3 buckets.

These keys are stored in the Cockpit team's Bitwarden (cockpit-infra-accounts).

Note: On some systems, the AWS CLI and Ansible may use the old `~/.aws/credentials` location. Both locations are supported.

S3 buckets
----------

We use two S3 buckets in the `us-east-1` region:

 * **cockpit-ci-images** - Test images (qcow2 files)
   - Console: https://us-east-1.console.aws.amazon.com/s3/buckets/cockpit-ci-images
   - URL: `https://cockpit-ci-images.s3.us-east-1.amazonaws.com/`
   - Uses per-file ACLs: non-RHEL images are `public-read`, RHEL images are `private`
   - No lifecycle policy (obsolete images pruned explicitly by tooling)

 * **cockpit-ci-logs** - CI test logs, artifacts, and Prometheus metrics
   - Console: https://us-east-1.console.aws.amazon.com/s3/buckets/cockpit-ci-logs
   - URL: `https://cockpit-ci-logs.s3.us-east-1.amazonaws.com/`
   - Public read via bucket policy (no per-file ACLs needed)
   - 90-day lifecycle policy for automatic cleanup

Create or update both buckets with:

    ansible-playbook aws/setup-s3-buckets.yml

SSH key
-------
For the initial access to created instances, this playbook creates a new `cockpit-$USER` key in AWS EC2 and saves the private key in `~/.ssh/id_aws.pem`:

    ansible-playbook aws/sshkey.yml

Now tell SSH to use it:

```
# internal and public instances
Host 10.29.*  *.compute-1.amazonaws.com
   User ec2-user
   IdentityFile ~/.ssh/id_aws.pem
   StrictHostKeyChecking no
   UserKnownHostsFile /dev/null
```

The [users role](../roles/users/tasks/main.yml) will change them to our regular keys. As ssh automatically falls back to your primary key, ssh still works.

Instances
---------

For doing anything RHEL related, we must use resources from the "us-east-1" region only. That has a "VPC ARR-US-East-1" network (vpc-097..) which is connected to a lot of useful [Red Hat internal resources](https://docs.google.com/document/d/1iDFmHbH0mtoy25OFI-0XyPWeTNOwWTd_LXb3e_q-Sa4).

For running tests we need to use [Nitro instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html#ec2-nitro-instances) that can do performant /dev/kvm. Only the `*.metal` types offer KVM, the virtualized ones don't have it at all (they are still good for image servers, though). The metal ones are rather expensive though -- the "cheapest" type is "c5.metal" which costs $4.08/h, i. e. about $100 a day.

Persistent resources
--------------------

 * eni-004f5b4f714f3fda9, aka "cockpit-public-webhook": network device with stable external IP 3.228.126.27 (DNS: ec2-3-228-126-27.compute-1.amazonaws.com)

Tasks runner setup
------------------

Create and configure the instance:

    ansible-playbook -i inventory aws/launch-tasks.yml

If you run more than one at a time, set a custom host name with `-e hostname=cockpit-aws-tasks-2` or similar, so that GitHub test statuses remain useful to identify where a test runs.

Webhook setup
-------------
Our primary webhook runs in CentOS CI. If that goes down, we can bring up a
fallback in AWS. Deploy or update it with:

    ansible-playbook -i inventory aws/launch-webhook.yml

Set project webhooks to point to http://ec2-3-228-126-27.compute-1.amazonaws.com
and the shared password found in our CI secrets (`webhook/.config/github-webhook-token`).

If you deploy this somewhere else, you need to change `DEFAULT_AMQP_SERVER` in
[bots](https://github.com/cockpit-project/bots/blob/main/lib/distributed_queue.py)
and change all GitHub project webhooks accordingly.

Cockpit demo setup
------------------

These can be used for usability studies, interactive demos, and similar purposes. They have public IPs, and a well-known `admin:foobar123` ssh/cockpit login, so don't keep them around for long!

The instances run RHEL 8 with the latest Cockpit release from [COPR](https://copr.fedorainfracloud.org/coprs/g/cockpit/cockpit-preview/).

 * Create a generic instance. If you need more than one instance, you can give the number in the `count` variable:

       ansible-playbook -i inventory -e count=2 aws/launch-demo.yml

 * Note down their DNS names (`ec2-*.compute-1.amazonaws.com`), these are the ones to hand out to study participants. These have ssh and cockpit running on the usual port 9090. You may want to ssh in and run `sudo hostnamectl set-hostname ...` for some meaningful names (particularly if you are testing the host switcher/Dashboard).

 * Then run any playbook in aws/demo/ specific for the system purpose that you want, for example:

       ansible-playbook -i inventory 2020-05-primary.yml

 * If you want to just run a specific role on a specific host you can do:

       ansible -i inventory -m include_role -a name=cockpit-demo-fakeupdates HOSTNAME
