Let's create and setup a LXC. First we need to download a LXC template we wish to be the base OS. In our case, we'll use Turnkey Core, but other templates may be used as well. Then we'll make modifications 

## Turnkey Core as LXC
**First**, download Turnkey Core template: `PVE -> isos -> CT Templates -> Turnkey Core`

**Second**, create a container using the template:
- In Proxmox, select "Create CT".
- General: Give it ID, hostname, and password. Make sure both *unprivileged container* and *nesting* are selected. If you plan on using Docker in the container, also check *keyctl* (although this may cause issues with *systemd-networkd*, but this issue may have already been fixed).
- Template: select proper template
- Disks: Give it about 20GB
- CPU: About 4 cores
- Memory: About 8192MB
- Network: Bridge should be vmbr0. Manually set IPv4 and have its IP match container ID for simplicity. Leave IPv6 blank (unless using IPv6).
- DNS: Don't have to put anything, but can if need be.

**Don't** start the container just yet. There's a few more setup steps.

## UID/GID Mapping
Because we're going to be setting up an unprivileged container and install Docker in the container, we're going to want to add storage. But the way Proxmox maps users/groups on unprivileged containers can lead to read/write permissions on storage added as a bind mount to that container. 

The default mapping for unprivileged containers provided by Proxmox is `lxc.idmap = u 0 100000 65536`. This default mapping specifies that the UID/GID range 0..65535 (guest) maps to the range 100000..165535 (host). Instead of using the default mapping, we'll create a custom UID/GID mapping that is more consistent. We will use this pattern on each container. 

In our case, we will map UID/GID=1000 (guest) → UID/GID=1000 (host).
### Prepare Host
In order for the mapping to work, we must allow the LXC into the mapping on host in the first place. We do this by modifying both `/etc/subuid` and `/etc/subgid` on the host. In the Proxmox shell, add to both files the line `root:1000:1`. This allows the user/group `root` to use exactly `1` UID/GID of `1000`. UID/GID=1000 (guest) will map to this namespace.

This only needs to be done once on the host (unless a system update changes these files).
### Modify Ownership of Storage
**For each storage you wish to mount to a container**, you must change the ownership to match the mapped UID/GID. For example:
`chown -R 1000:1000 /mnt/media`

### Map UID/GID in LXC Configuration
For each container with a bind mount, you'll need to manually specify the UID/GID mapping scheme you wish to use.

In the container's configuration file (found in `/etc/pve/lxc/xxx.conf`), add the following lines:
```yaml
lxc.idmap: u 0 100000 1000
lxc.idmap: g 0 100000 1000
lxc.idmap: u 1000 1000 1
lxc.idmap: g 1000 1000 1
lxc.idmap: u 1001 101001 64535
lxc.idmap: g 1001 101001 64535
```

The first and second lines specify that UID/GID=0 (guest) maps to UID/GID=100000 over a range of 1000 UIDs/GIDs. So 0..999 (guest) → 100000..100999 (host)

The third and fourth lines map only one single UID/GID of 1000 (guest) to 1000 (host). So 1000 (guest) → 1000 (host).

The fifth and sixth lines map the rest of the 65535 UIDs/GIDs starting at 1001 (guest) to 101001 (host). So 1001..65535 (guest) → 101001..165535 (host).
### Bind Mounts
Now let's add any bind mounts we need. 

**You can now create bind mounts directly in the Proxmox UI**. Alternatively, you can use the command line or edit the LXC's configuration file directly (found in `/etc/pve/lxc/xxx.conf`).

Go to the container's *resources* page and add a *mount point*. For the settings:
- Mount point ID: Leave default unless LXC has other mount points
- Storage: Select dataset storage you wish to use (e.g. `media`)
- Disk size: Set the size you wish. Max allowed is what Zpool offers.
- Path: path inside the container to the mount point (e.g. `/mnt/media`)

Or you can use the Proxmox shell to set the bind mount:
```bash
pct set 201 -mp0 /mnt/data,mp=/data
```
This command will mount the Proxmox directory `/mnt/data` to the directory `/data` on the container with a Proxmox ID of `201`. If you have other hardware mounted at `mp0`, you will need to increment those values to values that are still available.

If you use either the GUI or the `pct` to add the bind mount, you can see the changes in the configuration file:
```
mp0: /mnt/data,mp=/data
```
### Setup LXC
Start the LXC, if it's not already running, and execute these initial commands:
`apt clean && apt update && apt upgrade -y`

#### Map UID/GID on LXC
These next two steps are required on every new LXC you wish to create. 

Now we need to create a user and group on the container and map the UID/GID to the corresponding users and groups made previously.

```bash
useradd ryan -u 1000 -m -s /bin/bash
usermod -aG sudo ryan
# take ownership of bind mount directory
chown -R ryan:ryan /data
```

This will create the user `ryan` with a UID and GID of `1000`, create a home directory (`-m`), and set the user's login shell (`-s`) to `/bin/bash`.



## References
### Docker in LXC
https://du.nkel.dev/blog/2021-03-25_proxmox_docker/
https://thehomelab.wiki/books/promox-ve/page/setup-and-install-docker-in-a-promox-lxc-conainer
https://benheater.com/proxmox-run-docker-on-linux-containers-lxc/
https://www.cynicalsignals.com/installing-portainer-in-a-proxmox-lxc/ *

### Linux namespaces and UID/GID mapping
https://www.baeldung.com/linux/etc-subuid
https://access.redhat.com/articles/5946151
https://www.apalrd.net/posts/2023/tip_idmap/ *

## Notes
Mount point vs entry in .conf:
https://forum.proxmox.com/threads/lxc-mount-entry-vs-mp0.143146/
Both are bind mounts, but Proxmox is only aware of mp0 for backups and snapshots.

What about `/dev/net/tun`? Apparently needed when using Docker in unprivileged LXC. https://www.reddit.com/r/selfhosted/comments/1gkd3li/does_it_make_sense_to_use_docker_podman_rootless/

Issue: when creating LXC on ZFS dataset, Proxmox will automatically create a subvolume for that container. But if you try to make a mount point for the same dataset for another LXC, that new LXC will also get its own subvolume, meaning there are two different datasets for each LXC and they can't see one another. Solved: Don't use storage created by Proxmox, instead bind mount the ZFS dataset directly (example: `/mnt/media`).

`fuse-overlay` may not be needed anymore with ZFS filesystems. 

