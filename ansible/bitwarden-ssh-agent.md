Using Bitwarden as an SSH agent
===============================

If your SSH key lives on a Yubikey (and it does, right?), running Ansible
playbooks against our infrastructure can be painful: every single task on every
host requires a PIN entry and a physical touch.  Bitwarden can act as an SSH
agent, holding your key in memory and authorizing requests automatically until
the vault is locked.

Setup
-----

1. Install [Bitwarden](https://bitwarden.com/) from
   [Flathub](https://flathub.org/apps/com.bitwarden.desktop):

       flatpak install flathub com.bitwarden.desktop

2. In Bitwarden, click **New → SSH key** to generate a new key.  Add its
   public key to the `ssh-keys` file in the [users role](./roles/users/tasks/ssh-keys).

3. In Bitwarden, go to **File → Settings** and enable:

   - **Enable SSH agent**
   - Under "Ask for authorization when using SSH agent", select
     **Remember until vault is locked**

Usage
-----

Point `SSH_AUTH_SOCK` at the Bitwarden agent socket before running Ansible:

    export SSH_AUTH_SOCK=~/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock

You can also add something like this in your ssh config:

```
Host rhos-*
	IdentityAgent ~/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock
```

Verify it works.  If you've set up [openstack-ssh-config](./openstack-ssh-config),
you can just `ssh` to one of the hosts directly, or use an Ansible ping:

    ansible -i inventory all -m ping

You can add the `export` line to your shell profile to make it permanent, or
use it selectively when running Ansible.
