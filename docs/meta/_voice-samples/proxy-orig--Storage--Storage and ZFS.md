There are several ways setup storage on Proxmox. Later on, we will be covering ZFS as we consider it the best filesystem to use.
## Storage Options

### Directory
You can add a drive as a *directory*, which will act as mounted local storage for the system. Directories store files in `.raw` format. This is the most basic option.

### LVM and LVM-Thin
You can also use LVM or LVM-Thin, which are common for Linux-based virtual machines. 

### ZFS
Good [explanation](https://forum.proxmox.com/threads/how-to-set-up-zfs-for-use-among-multiple-lxc.168481/) of ZFS, Zpools, and Proxmox storage types.

ZFS is simultaneously a RAID array system, volume manager and the filesystem. ZFS allows you to pool drives together, create discrete filesystems on those pools, provide data redundancy and integrity across pools, and improve I/O performance.

ZFS maintains data integrity using **checksums** (hashing) for every block of data. When reading data, it verifies the checksum to ensure it hasn't been corrupted. If a failure occurs, ZFS can use the redundancy (parity or mirror) to rebuild the lost or corrupted data.

ZFS provides performance improvements in various ways. One of the most significant features is ARC (adaptive replacement cache). The ARC is a memory cache that stores frequently accessed data blocks. This allows ZFS to serve data much faster by reading from memory instead of accessing the slower disk storage. As the amount of data grows, ZFS will use more memory to maintain a large ARC, which speeds up performance, especially for read-heavy workloads, but may take up a good amount of system memory.

ZFS **pools** (*Zpools*) are pools of disks. When adding ZFS disks to a pool, you can select different RAID levels: single disk, mirror, RAID10, RAIDZ, RAID2, RAIDZ3. Mirror is RAID1. RAIDZs offer different levels of parity and is similar to RAID5. Once you have a ZFS pool, you can add **datasets** to that pool. You can add it as either a directory of ZHS storage (or other types). Snapshots and other features (for VMs) can only be added to ZHS storage types. Each dataset is similar to an independent (thin-provisioned) partition. Datasets have many uses, since they separate dataset-wide settings, snapshot boundaries, mount points and more.

By default you can also store a limited number of things on ZFS. To store more datatypes, you need to create a dataset (mounted folder) under the pool and then add that as a directory. Essentially, once you create the pool, you need to create a mount point (folder) as storage to actually store files. We will cover how to do this later in the article.

A few things to note: you don't have to check "add storage" when creating a ZFS pool. This will add the ZFS pool as an item under your PVE node. Technically you can store VMs and LXCs on the root dataset (which is created by default when the pool is created), but as a standard practice you shouldn't. ZFS is not recommended for use with hardware RAID. Multiple people and TrueNas have recommended **lz4** compression when creating Zpools.

#### Setting Up ZFS
There are three steps that need to be taken before we can get access to storage in our Proxmox system. We first need to create a ZFS **Zpool**, then create **datasets** with mount points on that pool, and finally we can add **storage** to that dataset for use on our Proxmox node. 

Two useful commands to start with are `zpool list` and `zfs list`. These commands will show the system's current zpools and datasets. 
##### Create ZPool
Let's use the GUI to create a ZFS pool of drives.
- Go to *node* -> *disks* -> *ZFS* -> *Create ZFS*
- Give ZFS pool name (`tank` is common), set RAID level, set compression to lz4.
- Select disks you wish to add to the Zpool.
- Uncheck *Add Storage*
	- **Note**: the content allowed in the storage created by Proxmox from a pool will be limited. Additionally, it's not recommended to store data on root pools anyhow. We'll create our own storage in the next steps. Unchecking this option means the Zpool won't appear as an option underneath the node after creation, which helps keep things clean.
- Press create

##### Create dataset on Zpool
Now we can add a dataset to our newly created Zpool.
- Go to the Proxmox shell
- Create a dataset with a mountpoint `zfs create [pool-name]/[dataset-name] -o recordsize=16K -o mountpoint=/mnt/[dataset-name]`
	- Example: `zfs create flash/vms -o mountpoint=/mnt/vms`
- `zfs mount -a`

You can view the changes with `zfs list`. 

**Note:** Later on, we will use bind mounts to pass datasets to containers. But bind mounts are not recursive, so if you wish to mount two different datasets that share a parent directory to a VM or LXC, you will have to manually mount each dataset. We use the `-o` flag to set the mount point on the host.

For example, suppose you had two datasets under `tank`:
`flash/vms`
`flash/docker`
If you mounted just `flash` to a container, you wouldn't see either `vms` or `docker`. You would need to individually mount both `vms` and `docker` as they are separate

##### Good beginning setup
Let's create several useful datasets for **vms**, **isos**, and **docker**:
```bash
# Flash pool datasets at 16k record size
## Create VMs dataset on flash for VMs and LXCs
zfs create flash/vms -o recordsize=16K -o mountpoint=/mnt/flash/vms

## Create main docker dataset for app configs 
zfs create flash/docker -o recordsize=16K -o mountpoint=/mnt/flash/docker ## Create individual app datasets 
zfs create flash/docker/radarr -o recordsize=16K 
zfs create flash/docker/qbittorrent -o recordsize=16K
zfs create flash/docker/prowlarr -o recordsize=16K
zfs create flash/docker/jellyfin -o recordsize=16K 

# Tank pool datasets at 128k record size
## Create ISO dataset on tank (bulk storage) 
zfs create tank/isos -o recordsize=128K -o mountpoint=/mnt/tank/isos

## Create Backups dataset on tank 
zfs create tank/backups -o recordsize=128K -o mountpoint=/mnt/tank/backups

## Create Media dataset on tank
zfs create tank/media -o recordsize=128K -o mountpoint=/mnt/tank/media

## Create special directory structure for Media and Backups
mkdir -p /mnt/tank/media/{movies,tv,music,torrents/{incomplete,complete}} mkdir -p /mnt/tank/backups/{proxmox,docker}

# Set ownership of guest user (LXCs) ran datasets
chown -R 1000:1000 /mnt/flash/docker 
chown -R 1000:1000 /mnt/tank/media 
# Set ownership of Proxmox ran datasets (default)
chown -R root:root /mnt/tank/backups
```

These commands create several useful and commonly used datasets such as `vms`, `isos`, `backups`, and `media`.

We add mountpoints for datasets that might not inherit from a parent. For example, `flash/docker/radarr` inherits its mountpoint from its parent `flash/docker`. If you add a dataset as storage, like what can be found below, the mountpoint will be set at creation in the arguments. 

We use a `recordsize` of `16k` for datasets that are expected to have high IO of small and media files such as `docker` and `vms`. We use a `recordsize` of `128k` for datasets that are expected to read/write large files such as `media`, `backups`, and `isos`. This will improve IO speeds.

For `media` and `backups`, we manually create regular directories. In the back of `media`, we need one filesystem for all media subdirectories to preverse Servarr stack hardlinks. In the case of `backups`, it's convenient to separate into subdirectories to keep directory structure clean. 

Finally, if you plan to use unprivileged LXCs, you will need to change the ownership of the datasets you wish to bind mount to an LXC. In this case, both `docker` and `media` will be access through bind mounts in a LXC, so the guest user needs proper permissions.

##### Add as storage
Some datasets need or can be added as storage. These storages will appear in the UI and are controlled by Proxmox. Both `vms` and `isos` are suitable candidates. 
```bash
# Add vms to Proxmox as ZFS pool storage
pvesm add zfspool vms --pool flash/vms --content images,rootdir

# Add isos to Proxmox as Directory storage 
pvesm add dir isos --path /mnt/tank/isos --content iso,vztmpl

# Add backups to Proxmox as Directory storage
pvesm add dir backups --path /mnt/tank/backups/proxmox --content backup
```

There are different types of storage. We use ZFS storage for `vms` because it provides backup and snapshot features and we use Directory storage for `backups` and `isos` and both usually use flat files. 

Alternatively, you can do this from the UI:
- Go to Datacenter -> Storage -> Add storage
- Select **ZFS** as storage type for most things, especially VMs and CTs. You can also use **directories**, but directories won't have features such as ZFS snapshots.
- Give ID, set directory to `/mnt/[dataset-name]` created previously, specify the content you want to allow.

Now you have a Zpool, a dataset on that Zpool, and storage setup on a dataset. The storage is now ready to use.




### References
- https://forum.proxmox.com/threads/lxc-mount-zfs-pool.147428/
- https://www.youtube.com/watch?v=HqOGeqT-SCA
- https://www.youtube.com/watch?v=oSD-VoloQag
- https://www.youtube.com/watch?v=m0dY4OJ9FWk
- https://free-pmx.github.io/insights/zfs-root/
- https://forum.proxmox.com/threads/how-to-set-up-zfs-for-use-among-multiple-lxc.168481/