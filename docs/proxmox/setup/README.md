# Proxmox Setup

## I. Proxmox

This guide covers the installation and setup of a **Proxmox VE** host. Proxmox VE is a Debian-based hypervisor that manages virtual machines and Linux containers (LXCs) through a web interface and CLI. It will help you install a fresh Proxmox VE install and turn it into the host described in this repository using the same storage layout, LXC conventions, Docker patterns, and automation model.

At a high level:

- A Proxmox VE 9 host (`pve01`) runs on bare metal. Other nodes may be added later.
- ZFS is used for all persistent storage, with explicit datasets and mountpoints
- Privileged LXCs are used as Docker hosts
- Docker Compose defines application stacks
- Ansible provisions the host and LXCs
- Komodo monitors and redeploys Docker stacks

## II. What You Will Build

Following this section from start to finish will produce a Proxmox host with a predictable ZFS dataset layout, a standard privileged Docker-in-LXC Docker pattern, and repeatable automations.

CT100 is the infrastructure container. It hosts Nginx Proxy Manager, Komodo Core, MongoDB, and a periphery agent. CT150 is the Servarr container. It hosts qBittorrent, Sonarr, Radarr, Lidarr, Prowlarr, and the shared `/data` layout used for downloads and media. Other containers will be added layer.

The system is built around host ZFS datasets and bind mounts rather than container states and network shares. Docker Compose files define the application stacks, Ansible provisions the repeatable parts of the build, and Komodo handles runtime deployment and normal stack operations.

## III. Host Identity (pve01)

This guide assumes that the host has the following values:

- Proxmox VE `9.1.4`
- host name `pve01`
- Management IP `192.168.1.19/24`
- Gateway/DNS `192.168.1.1`
- Bridge `vmbr0`
- Storage pools `flash` and `tank`
- Proxmox storage IDs `isos`, `vms`, `database`, and `backups`
- Debian LXC template `debian-13-standard_13.1-2_amd64.tar.zst`

## IV. Node Specific Hardware

For hardware details specific to this host, see [Hardware/pve01.md](../Hardware/pve01.md). This guide references that the hardware mentioned on that page, although this guide could be followed on other similar hardware.

## I. ZFS Pool Architecture

We utilize a multi-pool strategy to isolate different I/O patterns. This prevents high-latency bulk storage operations from slowing down the responsive "feel" of your virtual machines and containers.

- **`vms` Pool**: (SATA SSD Mirror)
  - **Workload**: OS Root filesystems (`rootfs`).
  - **Rationale**: Standard SSD speeds are more than sufficient for OS boot and system logs.
- **`flash` Pool**: (NVMe Mirror)
  - **Workload**: High-frequency random I/O (Databases, Docker configs, indexers).
  - **Optimization**: Set to **16K Recordsize**. Matches the block-size of most database engines (like PostgreSQL/MariaDB), reducing write amplification.
- **`tank` Pool**: (NVMe Mirror)
  - **Workload**: Large sequential I/O (Media files, ISOs, downloads).
  - **Optimization**: Set to **128K Recordsize**. Maximizes throughput for streaming and massive file transfers.

---

## II. The UID/GID 1000 Standard

"Permission Hell" is the most common failure point in homelab environments. To solve this, we enforce a strict **UID/GID 1000** standard across every layer of the stack.

- **Host Level**: Create a standard user (e.g., `ryan`) with UID 1000.
- **LXC Level**: Use **Privileged LXCs** so that UID 1000 inside the container maps directly to UID 1000 on the host ZFS datasets.
- **Docker Level**: Every container in the **[Servarr Stack](../../setup/08-servarr-stack.md)** is passed the environment variables `PUID=1000` and `PGID=1000`.

**Why UID 1000?**
It is the default ID assigned to the first non-root user on almost every Linux distribution (Ubuntu, Debian, Alpine). Standardizing on this ID ensures that a file written by a download client can be instantly moved or deleted by a media manager without `sudo` or permission errors.

---

## III. Atomic Moves and Hardlinks

This lab is designed for "Instant Management" of media. By utilizing a single top-level ZFS dataset for all media operations, we enable **Hardlinks**.

### The Directory Rule

All download and library folders **must** exist under the same ZFS dataset (e.g., `/mnt/media`).

- ✅ **Correct**: `/mnt/media/downloads` and `/mnt/media/movies`
- ❌ **Incorrect**: `/mnt/downloads` and `/mnt/movies` (if these are separate ZFS datasets).

**The Result**: When Sonarr "moves" a file from downloads to your library, it simply creates a second pointer to the same data blocks on the disk. The move is instantaneous, takes up 0 bytes of extra space, and allows you to continue seeding the original file.

---

## IV. Dataset Inheritance

We use ZFS properties to automate management. By setting properties at the pool or top-level dataset, we ensure all sub-folders follow the rules.

- **Compression**: `lz4` (Enabled by default; high performance, low CPU overhead).
- **Atime**: `off` (Prevents ZFS from writing to the disk every time a file is read, significantly reducing SSD wear).
- **Xattr**: `sa` (System Attribute storage; improves performance for Linux-based Extended Attributes).

---

## V. Maintenance Commands

Standard commands for managing this infrastructure:

- **Check Pool Health**: `zpool status`
- **Check Recordsize**: `zfs get recordsize <dataset>`
- **Fix Permissions**: `chown -R 1000:1000 /mnt/media`

## V. Reading Order

Read these files in order.

1. [01 — Host Baseline](01%20Host%20Baseline.md)
2. [02 — Storage and ZFS Layout](./02-storage-and-zfs-layout.md)
3. [03 — The Privileged LXC Pattern](./03-the-privileged-lxc-pattern.md)
4. [04 — Infrastructure LXC (CT100)](./04-infrastructure-lxc-ct100.md)
5. [05 — Servarr LXC (CT150)](./05-servarr-lxc-ct150.md)
6. [06 — Ansible Provisioning](./06-ansible-provisioning.md)
7. [07 — Komodo and Stack Deployment](./07-komodo-and-stack-deployment.md)
8. [08 — Operations and Backups](./08-operations-and-backups.md)

---

**Next step** → [02 — ZFS Performance Tuning](./02-zfs-performance-tuning.md)
