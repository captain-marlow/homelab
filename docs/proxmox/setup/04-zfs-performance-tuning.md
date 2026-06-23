# 04 — ZFS Performance Tuning

This document covers the creation and optimization of your ZFS storage pools. Based on real-world `fio` benchmarks performed on this specific hardware, we utilize a performance-driven approach to recordsize to ensure that high-IOPS application state and large-scale media operations both perform at their theoretical maximums.

---

## I. Pool Architecture

The physical storage consists of four NVMe drives organized into two distinct mirrored pools. This separation prevents high-frequency database writes from contending with large sequential media reads, ensuring no I/O wait-state overlap.

- **`flash` Pool**: 2× NVMe in ZFS Mirror (RAID1).
  - **Purpose**: Latency-sensitive application data, LXC root filesystems, Docker configurations, and databases.
- **`tank` Pool**: 2× NVMe in ZFS Mirror (RAID1).
  - **Purpose**: Bulk storage, media libraries, downloads, and large sequential file operations.

---

## II. The Science: Recordsize Optimization

Recordsize is the most critical ZFS property for tuning performance. Our benchmarks revealed that matching the recordsize to the expected workload type provides massive throughput gains.

- **16K Recordsize (Optimized for `flash`)**:
  - **Rationale**: Smaller blocks prevent "write amplification" where ZFS would otherwise write a full 128K block for a tiny 4K database update.
  - **Use Case**: OS operations, MongoDB/SQLite databases, and Docker application configurations.
- **128K Recordsize (Optimized for `tank`)**:
  - **Rationale**: Larger blocks allow ZFS to read and write data in huge, efficient chunks.
  - **Use Case**: Media streaming, sequential downloads, and large file backups.

---

## III. Creating Datasets and Mountpoints

Datasets are created explicitly on the Proxmox host with fixed mountpoints under `/mnt` to ensure predictability when bind-mounting into containers.

### Phase A: Create the Flash Dataset

- **Command**: `zfs create flash/docker -o recordsize=16K -o mountpoint=/mnt/flash/docker`
- **Explanation**: This dataset will hold all our Docker Compose files and container persistent data.

### Phase B: Create the Media Dataset

- **Command**: `zfs create tank/media -o recordsize=128K -o mountpoint=/mnt/media`
- **Explanation**: A single top-level dataset is used for all media to ensure that **atomic moves and hardlinks** function correctly across the Servarr stack. For more on the hardlink logic, see **[Proxmox Infrastructure Setup](../knowledge-base/proxmox/infrastructure-setup.md)**.

---

## IV. Directory Structure and Permissions

Persistent data is owned by a single non-root user (UID 1000) to standardize permissions across the host, LXCs, and Docker containers.

- **Initialize Media Structure**:
  - `mkdir -p /mnt/media/{torrents/{incomplete,complete},usenet,movies,tv,music,books}`
- **Apply Permissions**:
  - `chown -R 1000:1000 /mnt/flash/docker`
  - `chown -R 1000:1000 /mnt/media`
- **Rationale**: Using a consistent UID 1000 across the entire stack eliminates "Permission Denied" errors when moving files between the download client and the media managers.

---

## V. Verification

Confirm the datasets are mounted and properties are correctly inherited before proceeding to LXC creation.

- **Check Mounts**: `df -h | grep -E "(flash|tank)"`
- **Check Recordsize**: `zfs get recordsize flash/docker tank/media`
  - *Expected Result*: `flash/docker` should show `16K`, and `tank/media` should show `128K`.

---

**Knowledge Base References:**

- **[Proxmox Infrastructure Setup](../knowledge-base/proxmox/infrastructure-setup.md)**
- **[Proxmox Networking and Firewall](../knowledge-base/proxmox/networking-and-firewall.md)**

Proceed to the next file:
-> **[(05) The Privileged LXC Pattern](./05-the-privileged-lxc-pattern.md)**
