Resources for setting up CI in AWS
==================================

Initial URLs
------------

 * Sign in [with your kerberos ticket](https://auth.redhat.com/auth/realms/EmployeeIDP/protocol/saml/clients/itaws); this needs to be set up first for new users, ask Dominik Perpeet or Miroslav Vadkerti about it
 * The [User management console](https://console.aws.amazon.com/iam/home?#/users) shows the available users and their Access Keys. The Cockpit team CI uses the [arr-cockpit](https://console.aws.amazon.com/iam/home?#/users/arr-cockpit) user. Contact Miroslav Vadkerti about creating a new access key for you.

Credentials configuration
-------------------------
For interacting with AWS with these Ansible playbooks or with the [AWS CLI](https://docs.aws.amazon.com/cli/index.html), put your access key into ~/.aws/credentials, either with calling `aws configure`, or creating the file manually:

```ini
[default]
aws_access_key_id = AKIA...
aws_secret_access_key = yoursecret
```

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

The [users role](../roles/users/tasks/main.yml) will change them to our regular keys that we also use for e2e. As ssh automatically falls back to your primary key, ssh still works.

Instances
---------

For doing anything RHEL related, we must use resources from the "us-east-1" region only. That has a "VPC ARR-US-East-1" network (vpc-097..) which is connected to a lot of useful [Red Hat internal resources](https://docs.google.com/document/d/1iDFmHbH0mtoy25OFI-0XyPWeTNOwWTd_LXb3e_q-Sa4).

For running tests we need to use [Nitro instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html#ec2-nitro-instances) that can do performant /dev/kvm. Only the `*.metal` types offer KVM, the virtualized ones don't have it at all (they are still good for image servers, though). The metal ones are rather expensive though -- the "cheapest" type is "c5.metal" which costs $4.08/h, i. e. about $100 a day.

Persistent resources
--------------------

 * vol-0b18cf9e00b8e8646, aka "cockpit-images": cockpit images cache volume, to be used in image server
 * eni-0c3e7a5a5757c2d46, aka "cockpit-images": network device with stable internal IP 10.29.163.169
 * eni-02f3ebd876eded015, aka "cockpit-tasks": network device with stable internal IP 10.29.163.166
 * eni-0fece6d6c83cd9eca, aka "cockpit-public-sink": network device with stable external IP 54.89.13.31 (DNS: logs.cockpit.org)

Image server setup
------------------

 * Create the instance, attach the cache volume:

       ansible-playbook -i inventory aws/launch-image.yml

 * Run the setup playbooks:

       ansible-playbook -i inventory aws/setup-host.yml
       ansible-playbook -i inventory maintenance/sync-secrets.yml
       ansible-playbook -i inventory cockpituous/images.yml

 * Set up an ssh configuration for convenience:

       Host awsimages
          Hostname 10.29.163.169

Tasks runner setup
------------------

 * Create the instance:

       ansible-playbook -i inventory aws/launch-tasks.yml

 * Run the setup playbooks:

       ansible-playbook -i inventory aws/setup-host.yml
       ansible-playbook -i inventory maintenance/sync-secrets.yml
       ansible-playbook -i inventory cockpituous/tasks-systemd.yml

 * Enable more runners to fill up the 96 CPUs/188 GiB RAM:

       ansible -i inventory -m shell -a 'systemctl enable --now cockpit-tasks@{5..12}' tag_ServiceComponent_Tasks

 * Set up an ssh configuration for convenience:

       Host awstasks
          Hostname 10.29.163.166

Public log sink/server setup
----------------------------

 * Create the instance:

       ansible-playbook -i inventory aws/launch-public-sink.yml

 * Run the setup playbooks:

       ansible-playbook -i inventory aws/setup-host.yml
       ansible-playbook -i inventory maintenance/sync-secrets.yml
       ansible-playbook -i inventory cockpituous/sink.yml

 * Set up an ssh configuration for convenience:

       Host awssink
          Hostname logs.cockpit-project.org
          User ec2-user

The logs.cockpit-project.org domain (managed by Red Hat, ask sgallagh about it)
points to the stable IP 54.89.13.31 of that instance.

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
