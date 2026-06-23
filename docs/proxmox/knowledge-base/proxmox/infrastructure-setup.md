# Proxmox Infrastructure Setup

This manual details the underlying storage philosophy and user permission standards that enable the high-performance "Scientific Approach" of this homelab. It serves as the technical justification for the configurations found in the **[setup/](./../../setup/)** guides.

---

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

---

**Related Documentation:**

- **[(04) ZFS Performance Tuning](../../setup/04-zfs-performance-tuning.md)**
- **[(05) The Privileged LXC Pattern](../../setup/05-the-privileged-lxc-pattern.md)**
- **[Privileged vs Unprivileged LXCs](./privileged-vs-unprivileged-lxcs.md)**
