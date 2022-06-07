# e2e setup helpers

Here are some helpers for installing operating systems on the e2e cluster machines.

The `e2e-ssh.config` file is recommended to `Include` or copy-paste into your local `~/.ssh/config`.

The basic setup for a reinstall is to run an NFS server on one of the existing machines (helpers in the `nfs-server/` directory) and use iDRAC "Virtual Media" to do the install on another machine (helpers in the `idrac/` directory).
