In this tutorial we will cover how to setup LXCs, Docker and Portainer, and network shares.

There are debates about the viability and security of using LXC containers. The primary difference between a virtual machine and a LXC is that the VM has its own kernel, whereas the LXC shares its kernel with the host. Many consider this a dangerous security lapse. If someone were to break into a LXC and get to the kernel, they would then be able to access the host system and all of its guests. So there are decisions to be made when choosing between a virtual machine or a LXC.

Typically in a setup this, one would create a virtual machine and install Docker and Portainer inside. LXCs can also be used to run Docker, but require some setup to use properly. In this tutorial, we will setup an *unprivileged* LXC container and configure it to properly deal with user permissions, bind mounts, and GID/UID mapping.

There are pros and cons to this setup. Virtual machines don't share the kernel with the host, which means they take up all of the resources allotted. The LXCs, however, will only use *up to* the amount of resources allotted. This permits less resource usage and also over-provisioning. The drawback to LXCs include issues with security, management, and updates.

Another decision to make is whether to choose a LXC container that is *privileged* or *unprivileged*. Privileged containers are not recommended as they represent a significant security threat vector. If you choose to go unprivileged, there are extra steps to be taken to make sure it works properly while maintaining security.

Because guest containers sometimes access resources on the host, such as storage, Proxmox must map users and groups on the host to users and groups on the guest for read/write access. Privileged containers use a one-to-one mapping, meaning UID/GID=0 on the guest equals UID/GID=0 on the host. This is where the security issue lies. If a hacker gets access to the root user and kernel on a guest, it will also get root user and kernel access on the host.

Unprivilaged LXC containers, on the other hand, have UIDs/GIDs that are mapped to 100000 on the host. That means a root user in the LXC container with UID/GID=0 will have a UID/GID=100000 on the Proxmox host. This is a security feature so the root user in the container doesn’t have root access if they are able to escape their container. 

But this security feature leads to issues when mounting storage to the LXC container. Because we're using an unprivileged container for security reasons we need to setup a user and group to deal with various tasks, including user privileges related to bind mounting.

## Prepare Proxmox
Before proceeding to the next tutorial, first make sure Proxmox is up to date:
```bash
apt clean && apt update
```
### Create ZFS Datashares
We need to create a new ZFS datasets before we proceed. We will be using the Servarr stack in one of the LXCs for media such as movies and music.

We use `flash` as our `Zpool` and then create a new ZFS dataset called `docker`. For each Docker container we wish to use and have backups, we will create an entirely new dataset. Remember that datasets represents different filesystems, so each Docker container has its own filesystem. This will help us later with backups. 

```bash
# Create the main docker dataset on flash (performance pool) 
zfs create flash/docker -o recordsize=16K -o mountpoint=/mnt/flash/docker # Create individual app docker datasets zfs create flash/docker/radarr 
zfs create flash/docker/infrastructure/sonarr
zfs create flash/docker/infrastructure/radarr
zfs create flash/docker/infrastructure/lidarr
zfs create flash/docker/infrastructure/readarr
zfs create flash/docker/infrastructure/qbittorrent
zfs create flash/docker/infrastructure/prowlarr
zfs create flash/docker/infrastructure/jellyfin

# Set proper ownership for bind mounting to LXCs 
chown -R 1000:1000 /mnt/flash/docker
```
Here we created the dataset `flash/docker` and gave it a mount point of `/mnt/flash/docker`. We also gave it a record size of 16k as Docker uses mainly smaller files. A test was done during the creation of this tutorial using `fio` and 16k was better IO compared to 128k, except for large media files. 

Go into the Proxmox CLI and check your current ZFS setup: `zfs list`. Now create a new media dataset and subfolders inside of that dataset:
```bash
# Single dataset for all media 
zfs create tank/media -o recordsize=128K -o mountpoint=/mnt/media 
# Create subdirectories 
mkdir -p /mnt/media/{torrents/{incomplete,complete},usenet,movies,tv,music,books} 

# set ownership for each subdirectory created in /mnt/media
chown -R 1000:1000 /mnt/media
```
Later on we will use the subdirectories in the `media` dataset as mount points inside of the LXCs we want to give access. Hard linking works in this setup because `/media`, where all the subdirectories lie, counts as a filesystem. Even if you have separate LXCs mounting the same dataset, the hard links will work. For these subdirectories, and for the `docker` dataset, we won't add as a ZFS storage in Proxmox UI.

```bash
# Check all datasets were created correctly 
zfs list -r flash && zfs list -r tank # Check mount points 
df -h | grep -E "(flash|tank)" 
```


## Links
- Setup Samba network share
- Download Turnkey Core CT template
- Install Turnkey LXC
- Setup LXC properly
	- Create user and group on host and give ownership of relative shares
	- Map LXC user and group to host user and group
	- Bind shares to LXC in Proxmox using `pct`
	- Install and setup Docker
		- Make sure Docker is using proper using and runs as sudo
	- Install Portainer


## References


## Notes

