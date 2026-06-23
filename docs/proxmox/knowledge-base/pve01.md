# PVE01 Hardware Specifications

This document records the physical "As-Built" configuration of the primary Proxmox host (`pve01`). These specifications are the foundation for all architectural and storage decisions, particularly regarding ZFS pool performance and PCIe lane utilization.

---

## I. System Overview

- **Hostname**: `pve01`
- **Role**: Single-node Proxmox VE host
- **Motherboard**: **GIGABYTE X670E AORUS Xtreme** (AMD X670E Chipset, AM5 Socket)
- **Processor**: **AMD Ryzen 9 7950X3D** (16C/32T, 3D V-Cache)
- **Memory**: **64GB (2x32GB) G.SKILL Trident Z5 Neo RGB DDR5-6000 CL30**
- **Primary Network**: Integrated **Aquantia 10 GbE LAN** (currently operating at 1 GbE)

---

## II. Storage Inventory

The storage architecture utilizes SATA for the host OS and four NVMe slots for dedicated ZFS data pools.

### OS / Boot (SATA SSDs)

- **Drive A**: Crucial MX500 500 GB
- **Drive B**: Crucial MX500 500 GB
- **Configuration**: Proxmox VE installation / Host OS storage
- **Rationale**: Using SATA for the OS preserves all four high-speed M.2 slots for the NVMe data pools.

### Data Pools (ZFS Mirrors)

Your four NVMe drives are divided into two distinct pools based on their performance characteristics.

- **`flash` Pool**: (High-Performance App State)
  - **Drive 1**: WD Black SN850X 2 TB
  - **Drive 2**: WD Black SN850X 2 TB
- **`tank` Pool**: (Bulk Media/Sequential Storage)
  - **Drive 1**: Sabrent Rocket Q 2 TB
  - **Drive 2**: WD Blue SN570 2 TB

---

## III. PCIe and I/O Capability

The **GIGABYTE X670E AORUS Xtreme** provides a robust foundation for an NVMe-heavy build.

- **Quad M.2 NVMe Slots**: Fully utilized for the `flash` and `tank` ZFS mirrors.
- **PCIe 5.0 Support**: Future-proofing for high-speed add-in cards or storage upgrades.
- **USB 3.2 Gen2x2**: High-speed external connectivity for offsite backup syncs.

---

## IV. Design Implications

This hardware profile enables:

- **ZFS-First Storage**: Full NVMe-backed mirrors with high ARC performance due to DDR5 bandwidth.
- **Compute Overhead**: 32 threads ensure no resource contention when running multiple Docker-in-LXC stacks.
- **Predictable Latency**: Clean separation between OS, application state, and bulk media data.

---

## V. Maintenance and Thermal Monitoring

- **Cooling**: CPU and NVMe drives are adequately cooled; sustained workloads do not trigger throttling.
- **S.M.A.R.T.**: Monitor the **WD Black** and **Sabrent** drives for wear levels, as ZFS high-frequency writes can impact lifetime over several years.

---

**Related Documentation:**

- **[(03) Proxmox Host Baseline](../setup/03-pve-host-baseline.md)**
- **[(04) ZFS Performance Tuning](../setup/04-zfs-performance-tuning.md)**
- **[Proxmox Infrastructure Setup](../knowledge-base/proxmox/infrastructure-setup.md)**
