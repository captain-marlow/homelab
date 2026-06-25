### Hard Disk
If you're using a SSD, make sure to check the *Discard* option, which enables TRIM support.

### CPU
*Cores* really just means *logical cores*. A core is a physical core and a thread is a logical core.
### Memory
### Network

In general, it's good practice to separate the management interface and the VM network.
## Post-Install

After the OS is installed, remember to install the QEMU agent.
## VM Options

You can enable *Start at boot* if you want the VM to start when Proxmox starts. You can also change the *Start/Shutdown order* if one VM requires another. You can even delay the start time.