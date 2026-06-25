## LXC vs VM

Do docker in LXC? To use with ZFS, make sure overlay driver (overlay2 / fuse-overlayfs) in installed and enabled. This is better than the vfs driver if you're using ZFS. But apparently there are issues with the overlay driver when updating Proxmox. There can be issues with cgroup compatibilities with LXC + docker when updating Proxmox.

Note: Split dockers that need GPU into separate LXC container.

https://www.youtube.com/watch?v=hDR_1opHGNQ starting at 8. Does a decent job

Docker in LXC is still debatable
[https://www.reddit.com/r/Proxmox/comments/15dzpp4/docker\\\_containers\\\_in\\\_an\\\_lxc/](https://www.reddit.com/r/Proxmox/comments/15dzpp4/docker%5C_containers%5C_in%5C_an%5C_lxc/)

https://forum.proxmox.com/threads/docker-on-proxmox-vm-not-lxc-with-zfs-storage.133367/
https://www.reddit.com/r/homelab/comments/12hljjj/advantage_of_having_multiple_lxc_versus_using/
https://www.reddit.com/r/Proxmox/comments/16yb5em/what_is_the_most_common_or_popular_way_to_host/
https://forum.proxmox.com/threads/root-docker-in-unprivileged-lxc-safe-or-not.93548/
https://forum.proxmox.com/threads/what-is-the-most-common-or-popular-way-to-host-docker-containers-in-proxmox.134356/
https://thehomelab.wiki/books/promox-ve/page/setup-and-install-docker-in-a-promox-lxc-conainer

When using either LXC or VM, use Debian.

If you want to mount a share, remember to add *uid* and *guid* in *fstab*. 
https://youtu.be/_sfddZHhOj4?t=1797