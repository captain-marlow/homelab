## Managing VMs

The `qm` command is for managing VMs. `qm reboot`is a graceful shutdown, whereas `qm reset` and `qm stop` are destructive.

You can set options with `qm set --onboot 0 101`

To see data of a machine: `qm config 101` or `qm config 101 | grep cores`
## Managing LXCs

The command is `pct`, which stands for *Proxmox container tool*. Very similar to commands for VMs. 

To access the shell of a container: `pct enter 101`