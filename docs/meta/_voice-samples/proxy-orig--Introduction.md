Proxmox is a hypervisor for virtualization.

REWRITE THIS INTRO BASED ON THIS VIDEO https://www.youtube.com/watch?v=qmSizZUbCOA

## Initial Setup
Create bootable USB, install onto machine. Use ZFS RAID 1. Proxmox doesn't boot from USB drive, so you'll have to use a standard drive.

After login, update Proxmox first. Go to your node and select "updates". 

If you don't plan on buying a subscription, you may want to add the "no subscription" repository to the update section. But don't do this for production environments To do this, select *repositories* under *updates* and press *add*. In the dropdown, select *no-subscription*. Reboot after updates. 

## VMs vs LXCs

Containers are a semi isolated user space that can be used to separate applications. Containers are an entire OS, except the kernel. Containers share the kernel with the system and use less resources. For example, if you give 1GB of memory to a VM, it will use it all, whereas the container will use *up to* 1GB. LXCs are better for directly accessing host storage. They can only be Linux because containers share most of the hosts resources. Because of this sharing, there are some security downsides to LXCs. If a kernel panic occurs inside a container, it will also happen on the host. Privileged containers run as root.

One downside to containers is that they have less application support compared to VMs. Some vendors will deny you support if they discover you're using a LXC. Another downside to containers is *migrations*. Live migrations are not possible with LXCs, meaning containers must shutdown in order to migrate. Note that if you want to run something that requires a lot of networking, LXCs can be difficult to configure as they require ip-table edits on the host.

You can use a container to passthrough a GPU to multiple applications (Jellyfin, etc.).

Turnkeys are like templates for containers. For example, there is a Nextcloud turnkey for Debian.

LXCs can have issues when Proxmox updates. Make sure to test new configs after updating Proxmox.

General rules of thumb:

- Use containers by default and if you run into significant issues, switch to a VM
- Use VM for non-linux OSs (Win/Mac/FreeBSD)

### Docker

You can run docker in either a container or a VM. There's a debate which is better, but LXCs have come a long away. If you put docker inside a container, make sure to enable \*keyctl \*and *nesting*. Another issue named volume data inside unprivileged containers. You can map host UIDs/GIDs to the LXC to get around this. Also make sure to enable fuse-overlay driver.

* * *
## Recommended
It's always a good idea to keep an OS update to date. Go to a node and select *Updates*. Refresh to see available updates. If you don't have a subscription, go to *Repositories* below and add the no subscription repo.
### Users
There are two realms for users. PAM refers to the user management of the underlying host system, essentially just Linux authentication. There's a difference between PAM users and Proxmox users, especially where the user is created and where that information is stored.

If you create a PAM user, you'll notice (by checking /etc/passwd) that the user was not added. Adding a user through the GUI requires an additional step, which is just the standard way to add a user in Linux. Open the Proxmox shell and add your user:

`adduser ryan`

`usermod -aG sudo ryan`

A Proxmox user is not a Linux system user. PAM users are Linux users, so they can SSH. 

Create a new group called *admin*. Add group permissions with the path / and the group *admin*. Add *role* of administration. Add your user to that group in *Users*. 

Summary:

PAM users are Linux users. It takes two steps to create a PAM user. You create the user in the system itself (via CLI) then add that user as a PAM user in the GUI. 

A PVE user is created in a single step. You create it in the GUI and it can only access and control Proxmox through the GUI, not SSH. 

PAM users are typically for users who will be using SSH.