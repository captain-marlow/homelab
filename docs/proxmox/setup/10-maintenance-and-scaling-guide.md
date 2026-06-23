# 10 — Maintenance and Scaling Guide

This document provides a roadmap for the long-term health of your homelab. It transitions from the "Build" phase into the "Operational" phase, focusing on security updates, storage expansion, and proactive performance monitoring.

---

## I. The Update Cycle

Regular updates are essential for security, but in a production-style homelab, they must be performed systematically to avoid unexpected service disruptions.

- **pfSense Updates**: Check for updates monthly. Always perform a manual configuration backup (**Diagnostics -> Backup & Restore**) before upgrading the firmware.
- **Proxmox Host (pve01)**: Run updates via the GUI or terminal using `apt update && apt dist-upgrade`.
  - *Rationale:* Kernel updates require a host reboot, which will take down all LXCs and Docker services. Schedule these for low-traffic windows.
- **Docker Containers**: Update by running `docker compose pull` followed by `docker compose up -d` in the relevant directory.
  - *Tip:* Consider running **Watchtower** in "monitor-only" mode to receive notifications when new images are available without allowing it to auto-update and potentially break configurations.

---

## II. Storage Expansion (Scaling ZFS)

As your media library grows, you will eventually outgrow the initial `tank` pool. ZFS allows for seamless capacity scaling.

- **Adding Capacity**: The safest way to expand a mirror pool is to add another pair of identical drives as a new VDEV. This increases both space and IOPS.
  - `zpool add tank mirror /dev/disk/by-id/NEW_DISK_A /dev/disk/by-id/NEW_DISK_B`
- **Drive Replacement**: If a drive fails or you wish to upgrade to larger disks, use the `zpool replace` command to swap one disk at a time and allow the mirror to "resilver."
  - *Technical Reference:* For more on ZFS resilience, see **[Proxmox Infrastructure Setup](../knowledge-base/proxmox/infrastructure-setup.md)**.

---

## III. Log Hygiene and Disk Space

Unmanaged logs and cached Docker layers can slowly consume your `flash` pool, eventually causing service crashes.

- **Check Disk Usage**: Use the `ncdu` tool on the host to find large, unexpected directories.
- **Pruning Docker**: Run `docker system prune` occasionally within your LXCs to remove old images, stopped containers, and unused networks that are no longer needed.
- **Journalctl Management**: Limit the size of the systemd journal to prevent it from growing indefinitely.
  - Edit `/etc/systemd/journald.conf` and set `SystemMaxUse=500M`.

---

## IV. Vertical vs. Horizontal Scaling

When a single LXC begins to hit resource limits, you have two primary paths for scaling:

- **Vertical Scaling**: Increase the CPU cores or RAM allocated to the LXC in the Proxmox "Resources" tab.
- **Horizontal Scaling**: Move specific services to a new, dedicated LXC.
  - *Example:* If Jellyfin video transcoding is slowing down the Servarr stack, move Jellyfin to its own privileged LXC (CT160) and perform a GPU passthrough for hardware acceleration.

---

## V. Proactive Hardware Monitoring

Hardware failure is a matter of "when," not "if." Early detection is the only way to prevent data loss.

- **ZFS Scrubs**: Proxmox typically schedules these automatically. Verify they are running monthly using `zpool status`.
- **SMART Tests**: Install `smartmontools` and check drive health periodically to look for increasing sectors or wear leveling counts.
  - `smartctl -a /dev/nvme0n1`
- **pfSense Notifications**: Ensure **[pfSense Networking and Routing](../knowledge-base/pfsense/networking-and-routing.md)** is configured to alert you via email or Telegram if a VPN gateway fails or the system reboots.

---

**Knowledge Base References:**

- **[pfSense Networking and Routing](../knowledge-base/pfsense/networking-and-routing.md)**
- **[Proxmox Infrastructure Setup](../knowledge-base/proxmox/infrastructure-setup.md)**
- **[Privileged vs Unprivileged LXCs](../knowledge-base/proxmox/privileged-vs-unprivileged-lxcs.md)**

This concludes the primary build documentation sequence. For deep-dives into specific troubleshooting or advanced security hardening, refer to the **Knowledge Base** manuals.
