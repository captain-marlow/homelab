# Proxmox Homelab: Hardened Media & Infrastructure

This repository contains the complete documentation and configuration logic for a high-performance Proxmox VE homelab. The architecture is built on a "Hard Fail-Closed" philosophy, ensuring that all media-related traffic is encrypted, authenticated, and strictly routed through a VPN failover group.

---

## 🚀 The Architecture at a Glance

* **Host**: Single-node Proxmox VE on **AMD Ryzen 9 7950X3D**.
* **Networking**: pfSense-driven with **WireGuard (Mullvad)** failover and encrypted **Quad9 DNS-over-TLS**.
* **Storage**: ZFS multi-pool strategy (`flash` vs `tank`) with optimized recordsizes for database and sequential I/O.
* **Automation**: **Docker-in-LXC** (Privileged) standardized on **UID 1000** for seamless ZFS bind-mount permissions.

---

## 📂 Documentation Menu

### 🛠️ [Setup Guides](./setup/)

*Follow these steps in order to rebuild the lab from scratch.*

1. **[01 — pfSense Base and VPN Failover](./setup/01-pfsense-base-and-vpn.md)**: WireGuard tunnels, Mullvad API registration, and Kill-Switch logic.
2. **[02 — pfSense Hardened DNS](./setup/02-pfsense-hardened-dns.md)**: DNS-over-TLS, NAT redirection, and pfBlockerNG.
3. **[03 — Proxmox Host Baseline](./setup/03-pve-host-baseline.md)**: Initial PVE hardening and repository setup.
4. **[04 — ZFS Performance Tuning](./setup/04-zfs-performance-tuning.md)**: Recordsize optimization and dataset creation.
5. **[05 — The Privileged LXC Pattern](./setup/05-the-privileged-lxc-pattern.md)**: The "Gold Standard" for Docker-in-LXC.
6. **[06 — Ansible Orchestration](./setup/06-ansible-orchestration.md)**: Infrastructure-as-Code for container deployment.
7. **[07 — Infrastructure Stack (CT100)](./setup/07-infrastructure-stack.md)**: Nginx Proxy Manager, Komodo, and MongoDB.
8. **[08 — Servarr Stack (CT150)](./setup/08-servarr-stack.md)**: Media automation with atomic move/hardlink logic.
9. **[09 — Post-Install and Backup](./setup/09-post-install-and-backup-strategy.md)**: ZFS snapshots, PBS, and offsite sync.
10. **[10 — Maintenance and Scaling](./setup/10-maintenance-and-scaling-guide.md)**: Long-term health and pool expansion.

---

### 📚 [Knowledge Base](./knowledge-base/)

*Deep-dive manuals explaining the technical "Why" behind the architecture.*

* **[pfSense Networking & Routing](./knowledge-base/pfsense/networking-and-routing.md)**: MTU/MSS logic and policy routing.
* **[pfSense DNS & Security](./knowledge-base/pfsense/dns-and-security.md)**: Encryption mechanics and hijacking prevention.
* **[Proxmox Infrastructure Setup](./knowledge-base/proxmox/infrastructure-setup.md)**: ZFS inheritance and UID 1000 standards.
* **[Proxmox Networking & Firewall](./knowledge-base/proxmox/networking-and-firewall.md)**: Bridge architecture and management rules.
* **[Privileged vs Unprivileged LXCs](./knowledge-base/proxmox/privileged-vs-unprivileged-lxcs.md)**: UID shifting vs. native performance.

---

### 🖥️ [Hardware Specs](./PVE01/)

*Specific inventory and PCIe mapping for the host node.*

* **[PVE01 Hardware](./PVE01/PVE01 Hardware.md)**: Ryzen 9 7950X3D, 64GB DDR5, and NVMe inventory.

---

## ⚠️ Core Principles

* **Atomic Operations**: Files are moved instantaneously using ZFS hardlinks; no "copy-paste-delete".
* **Hard Fail-Closed**: If the VPN or DNS-over-TLS fails, the connection drops. No data leaks to the ISP.
* **Permission Standard**: All persistent data is owned by UID 1000 to eliminate cross-container permission errors.
