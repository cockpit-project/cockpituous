Testing against a local VM
---------------------------

You can run the Ansible playbooks or roles against a local VM for development.
There is a [localvm inventory](../inventory/localvm) which adds the
[standard cockpit](https://github.com/cockpit-project/cockpit/blob/main/test/README.md#convenient-test-vm-ssh-access)
`c` SSH machine. Start e.g. a `fedora-coreos` or `fedora-39` VMs about

Launch a task runner with

    ansible-playbook -i inventory localvm/launch-tasks.yml
