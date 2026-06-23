## I. ZFS Storage

All storage on our Proxmox host is managed using ZFS. We use ZFS instead of directory or LVM storage because it provides:

- Data integrity 
- Explicit datasets with fixed mountpoints
- Reliable snapshots and replication
- Clear separation between different categories of data
- Predictable behavior under container and Docker workloads

There are two ZFS pools on the host, `flash` and `tank` each backed by its own pair of NVMe drives in a ZFS mirror. `flash` is used for primary applications whereas `tank` is used mostly for bulk storage. 

> **Knowledge Base**: For the full storage philosophy, pool architecture rationale, and how atomic moves work, see [Infrastructure Setup](../knowledge-base/infrastructure-setup.md).

You can create the pools in the Proxmox GUI or on the CLI. Use whichever you prefer.

## II. Create Zpools

### GUI method (recommended)

In the GUI: **Datacenter** -> **pve01** -> **Disks** -> **ZFS** -> **Create: ZFS**.

Create these two pools:

- Pool name: `flash`
  - RAID level: `Mirror`
  - Select the two NVMe drives reserved for fast application storage
  - Compression: lz4
- Pool name: `tank`
  - RAID level: `Mirror`
  - Select the two NVMe drives reserved for media, ISOs, and backups
  - Compression: lz4

> **Note:** `compression=lz4` is recommended for general ZFS use and is part of the standard baseline in this homelab.

### CLI method

If you prefer the CLI, you may use the commands below. Replace the `/dev/disk/by-id/...` values below with the actual drive IDs from your system.

```bash
zpool create -f \
  -o ashift=12 \
  flash mirror \
  /dev/disk/by-id/FLASH_DRIVE_1 \
  /dev/disk/by-id/FLASH_DRIVE_2

zpool create -f \
  -o ashift=12 \
  tank mirror \
  /dev/disk/by-id/TANK_DRIVE_1 \
  /dev/disk/by-id/TANK_DRIVE_2
```

After creating the pools, verify them:

```bash
zpool status
```

Now that we have **Zpools**, we can create **datasets** on those pools.

## III. Create the Canonical Datasets

**Datasets** are used to actually store data. 

There are many common **datasets** you will find in Proxmox. These include `vms`, `isos`, and `backups`. We will also add some other useful datasets that we will utilize later.

A note on recordsizes and mountpoints:
`flash/docker` and `flash/database` use `recordsize=16K` for small random writes. `tank/media` and `tank/backups` use `recordsize=128K` for large sequential files.

Create the datasets with the following commands.
```bash
zfs create flash/vms -o mountpoint=/mnt/flash/vms
zfs create flash/docker -o recordsize=16K -o mountpoint=/mnt/flash/docker
zfs create flash/database -o recordsize=16K -o mountpoint=/mnt/flash/database
zfs create tank/media -o recordsize=128K -o mountpoint=/mnt/tank/media
zfs create tank/backups -o recordsize=128K -o mountpoint=/mnt/tank/backups
zfs create tank/isos -o mountpoint=/mnt/tank/isos
```

These are the canonical top-level datasets used throughout the rest of the docs. Create them exactly once and keep the mountpoints stable.

For just the `tank/media` directory, we will create plain Linux directories so that hardlinks will work later when we use the Sonarr apps.

```bash
mkdir -p /mnt/media/{torrents/{incomplete,complete},usenet,movies,tv,music,books}
```

## VI. Verification

Before moving on to container creation, confirm that both datasets are mounted and their properties are set correctly. A misconfigured recordsize can't be changed after the dataset has data on it — you'd have to create a new dataset and migrate, so it's worth catching now.

```bash
df -h | grep -E "(flash|tank)"
zfs get recordsize flash/docker tank/media
```

Expected output: `flash/docker` shows `16K`, `tank/media` shows `128K`. If either value is wrong, destroy the dataset (`zfs destroy <dataset>`), and recreate it with the correct recordsize before proceeding.


---
Proceed to the next file:

-> [03 — Storage and ZFS Layout](./02-storage-and-zfs-layout.md)