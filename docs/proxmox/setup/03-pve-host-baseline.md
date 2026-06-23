# 03 — Proxmox Host Baseline

This document covers the installation and initial hardening of the Proxmox VE host (`pve01`). The goal is to establish a stable, updated platform with predictable networking and storage before creating any containers.

---

## I. Proxmox Installation

- **Boot Media:** Standard Proxmox VE 9.x ISO.
- **Target Drive:** Mirror (RAID1) using the two 500GB SATA SSDs. [Link: **[PVE01 Hardware](../PVE01/PVE01 Hardware.md)**]
  - *Rationale:* Placing the OS on dedicated SATA SSDs preserves all four high-performance NVMe slots for the ZFS data pools (`flash` and `tank`).
- **Filesystem:** ZFS (RAID1).
- **Advanced Options:** Set `hdsize` to leave at least 8-10GB of unallocated space at the end of the disks to ensure ZFS has enough "breathing room" for metadata and to account for slight variations in disk sizes between vendors.

---

## II. Host Identity and Baseline Networking

During installation, set the following parameters to align with the network backbone established in **[pfSense Base and VPN Failover](./01-pfsense-base-and-vpn.md)**.

- **Hostname:** `pve01.local` (or your preferred internal domain).
- **Management IP:** `192.168.1.19/24`.
- **Gateway:** `192.168.1.1` (pfSense).
- **DNS Server:** `192.168.1.1` (pfSense).
  - *Rationale:* By pointing the host's DNS to pfSense, the host itself benefits from the **[pfSense DNS and Security](../knowledge-base/pfsense/dns-and-security.md)** logic, ensuring host-level updates are resolved securely.

---

## III. Post-Install Optimization (Repositories)

Proxmox defaults to the enterprise (paid) repository. For this homelab, we must switch to the community-supported "No-Subscription" repository to enable updates.

- **Step 1:** In the Proxmox GUI, select the `pve01` node -> **Repositories**.
- **Step 2:** Disable the `pve-enterprise` repository.
- **Step 3:** Click **Add** and select `No-Subscription` from the dropdown.
- **Step 4:** Navigate to **Updates** and click **Refresh**, then **Upgrade**.
  - *Rationale:* This ensures your host has the latest security patches and kernel features required for stable Docker-in-LXC performance.

---

## IV. User Management and Security

We distinguish between Linux system users (PAM) and Proxmox-only users (PVE).

- **Standard Admin User:** Create a Linux user via the CLI (e.g., `adduser ryan`) and add them to the `sudo` group.
- **Proxmox Permissions:** In **Datacenter -> Permissions -> Users**, add the Linux user as a **PAM** user.
- **Role Assignment:** Assign the user the `Administrator` role at the `/` (root) path.
  - *Technical Reference:* For more on the differences between user realms, see **[Proxmox Infrastructure Setup](../knowledge-base/proxmox/infrastructure-setup.md)**.

---

## V. Firewall Safety Warning

Proxmox includes a built-in firewall, but it is disabled by default.

- **Critical Warning:** Do **NOT** enable the firewall at the Datacenter or Node level until you have explicitly created an **ACCEPT** rule for the management port (`8006`).
- **Required Rule:**
  - Direction: `In` | Action: `ACCEPT` | Port: `8006` | Source: `Optional` (or your Admin Workstation IP).
  - *Rationale:* Enabling the firewall without a management rule will immediately lock you out of the web interface. See **[Proxmox Networking and Firewall](../knowledge-base/proxmox/networking-and-firewall.md)** for safe configuration patterns.

---

**Knowledge Base References:**

- **[Proxmox Networking and Firewall](../knowledge-base/proxmox/networking-and-firewall.md)**
- **[Proxmox Infrastructure Setup](../knowledge-base/proxmox/infrastructure-setup.md)**

Proceed to the next file:
-> **[ZFS Performance Tuning](./04-zfs-performance-tuning.md)**
