Resources for setting up CI in PSI OpenStack
============================================

We have a "front-door-ci" project on the PSI OpenStack clouds rhos-d and rhos-01. The latter's nested KVM support and performance is good enough for our tasks runners.

Access
------
Sign into the OpenShift web console on https://api.rhos-01.prod.psi.rdu2.redhat.com with the usual "Red Hat Employment SSO" method. You need to be in the [front-door-ci group](https://rover.redhat.com/groups/group/front-door-ci) for this.

The only change that was, and currently needs to be done manually is to add SSH, HTTP, and ICMP to the "default" security group. This step may be automated in the future.

Automation setup
----------------

You need to install the OpenStack SDK, either with `sudo dnf install python3-openstacksdk` (on Fedora), or `pip install openstacksdk`.

After that, you need to set up `~/.config/openstack/clouds.yml`. If you don't already have one, copy or symlink [clouds.yml](./clouds.yml), otherwise merge it with your existing one. You need to create a file `~/.config/openstack/secure.yaml` for your credentials, see the comment in [clouds.yml](./clouds.yml) for how to do that.

Check that this works with

    ansible-inventory -i inventory/openstack.yml -v --yaml --list

Tasks runner setup
------------------
We don't have very big flavors on this cloud, so each tasks instance can run just one tasks bot.

Create and configure an instance with

    ansible-playbook -i inventory -e instance_name=rhos-01-1 psi/launch-tasks.yml

For the time being there is no dynamic scaling, so do this for rhos-01{1..16} (as much as your quota allows).

You can run [deploy-all.sh](./deploy-all.sh) to mass-deploy all instances. Existing instances are deleted first.

All cloud/PSI specific parameters are in [psi_defaults.yml](./psi_defaults.yml), please edit/extend that instead of hardcoding cloud specifics in roles or playbooks.

Image cache
-----------
We also run an S3 image server on the first instance (defined in [ansible/inventory/psi_s3](../inventory/psi_s3)), mostly as a local cache. Otherwise image download during tests is too slow and repeated too often. Set this up with

    ansible-playbook -i inventory psi/image-cache.yml

This needs to be run whenever the first instance gets redeployed.

SSH access
----------
The instances run our usual [users role](../roles/users/), so if you are in the [ssh-keys](../roles/users/tasks/ssh-keys) list, you can SSH to the instances. Run [`./openstack-ssh-config`](../openstack-ssh-config) to generate an SSH configuration file from the dynamic inventory, and follow the instructions. Then you can do e. g. `ssh rhos-01-1`.
