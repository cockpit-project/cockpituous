Resources for setting up CI in PSI OpenStack
============================================

We have a "front-door-ci" project on the PSI OpenStack clouds rhos-d and rhos-01. The latter's nested KVM support and performance is good enough for our tasks runners.

Access
------
Sign into the OpenShift web console on https://api.rhos-01.prod.psi.rdu2.redhat.com with domain "redhat.com", your RedHat user name, and your Kerberos password. You need to be in the [front-door-ci group](https://rover.redhat.com/groups/group/front-door-ci) for this.

The only change that was, and currently needs to be done manually is to add SSH and ICMP to the "default" security group. This step may be automated in the future.

Automation setup
----------------

You need to install the OpenStack SDK, either with `sudo dnf install python3-openstacksdk` (on Fedora), or `pip install openstacksdk`.

After that, you need to set up `~/.config/openstack/clouds.yml`. If you don't already have one, copy or symlink [clouds.yml](./clouds.yml), otherwise merge it with your existing one. You need to create a file `~/.config/openstack/secure.yaml` for your credentials, see the comment in [clouds.yml](./clouds.yml) for how to do that.

Check that this works with

    ansible-inventory -i inventory/openstack.yml -v --yaml --list

Fedora CoreOS image import
--------------------------
The PSI cluster only has outdated Fedora images, and no CoreOS. So we import
these ourselves. Before doing a bigger deployment, import the current version
with [import-coreos.sh](./import-coreos.sh). See the script header for
requirements.

Tasks runner setup
------------------
We don't have very big flavors on this cloud, so each tasks instance can run just one tasks bot.

Create and configure an instance with

    ansible-playbook -i inventory -e instance_name=rhos-01-1 psi/launch-tasks.yml

For the time being there is no dynamic scaling, so do this for rhos-01{1..16} (as much as your quota allows).

All cloud/PSI specific parameters are in [psi_defaults.yml](./psi_defaults.yml), please edit/extend that instead of hardcoding cloud specifics in roles or playbooks.

The instances run our usual [users role](../roles/users/), so if you are in the [ssh-keys](../roles/users/tasks/ssh-keys) list, you can SSH to the instances with `ssh core@10.X.X.X`.
