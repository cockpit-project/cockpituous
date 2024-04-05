Setup/maintenance Ansible playbooks for Front Door CI
=====================================================

 * [inventory](./inventory/): Ansible machine groups for our machines in all clouds
 * [aws](./aws/): Documentation and playbooks for lauching and configuring CI in Amazon Web Services EC2
 * [psi](./psi/): Documentation and playbooks for lauching and configuring CI in RedHat PSI OpenStack
 * [roles](./roles/): Ansible roles for common setup steps
 * [maintenance](./maintenance/): Ansible playbooks for maintenance tasks on all CI machines

Testing against a local VM
---------------------------

You can run the Ansible playbooks or roles against a local VM for development.
There is an example [localvm inventory](./inventory/localvm) which adds the
[standard cockpit](https://github.com/cockpit-project/cockpit/blob/main/test/README.md#convenient-test-vm-ssh-access)
`c` SSH machine. Start e.g. a `fedora-coreos` or `fedora-39` VM, and locally
adjust the `hosts:` playbook you are working on from e.g. `openstack_tasks` to
`localvm` (the playbooks don't do that by default to avoid errors about
unreachable host).
