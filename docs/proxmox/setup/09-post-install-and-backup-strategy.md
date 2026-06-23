# 09 — Post-Install and Backup Strategy

This document establishes the "Safety Net" for the lab. Once the Infrastructure and Servarr stacks are operational, we must implement an automated backup strategy that handles both the Proxmox host configuration and the persistent Docker data stored on ZFS.

---

## I. Proxmox Backup Server (PBS) or Local Backups

A lab is only as stable as its last backup. We prioritize backing up the LXC configurations and their small root disks (`rootfs`).

- **Target Storage:** A dedicated external drive or a separate NAS share.
- **Schedule:** Daily at 03:00 AM.
- **Retention Policy:** - Keep last 7 daily backups.
  - Keep last 4 weekly backups.
- **Implementation:**
  - Go to **Datacenter -> Backup -> Add**.
  - Select all LXCs (`100`, `150`).
  - **Rationale:** In the event of a host failure, we can restore the LXC shells in minutes. Since the heavy data lives on ZFS datasets, the backup files remain small and fast to transfer.

---

## II. ZFS Snapshot Strategy

For the bulk data and application configurations stored on `flash` and `tank`, we use ZFS snapshots. Snapshots are "frozen" versions of the dataset that allow for near-instant recovery from accidental deletions or database corruption.

- **Tools:** `Sanoid` (Automated snapshotting) or standard Cron jobs.
- **Configuration:**
  - **`flash/docker`**: Snapshots every hour (kept for 24 hours).
  - **`tank/media`**: Snapshots every day (kept for 30 days).
- **Manual Snapshot Command:**
  - `zfs snapshot flash/docker@pre-update-$(date +%Y-%m-%d)`
- **Rationale:** Always take a manual snapshot before performing major updates to the Servarr stack or Nginx Proxy Manager.

---

## III. Offsite Data Protection (Rclone)

Snapshots on the same pool do not protect against physical hardware failure. We use Rclone to sync critical application configurations to an offsite cloud provider (e.g., Backblaze B2, Proton Drive).

- **Scope:** **ONLY** the `/mnt/flash/docker` directory (configs and databases).
- **Exclusion:** Do **NOT** backup `/mnt/media` unless you have unlimited bandwidth and storage; media is reproducible, whereas your Radarr database and custom scripts are not.
- **Standard Command:**
  - `rclone sync /mnt/flash/docker remote:pve-backups/infrastructure`

---

## IV. Monitoring and Notifications

To ensure you aren't flying blind, pfSense and Proxmox must be configured to alert you of hardware or service failures.

- **pfSense Notifications:** Go to **System -> Advanced -> Notifications**. Enable Telegram or Email alerts for Gateway Failover events.
- **Proxmox Alerts:** Ensure the `postfix` service is configured to relay system mail.
- **Uptime Kuma:** (Optional) Deploy a container in the Infrastructure LXC to monitor the HTTP status of your Servarr apps and the health of the Mullvad VPN tunnels.

---

## V. Final Verification Checklist

Before considering the build "Complete," verify the following:

1. [ ] **Failover Works:** Unplug/Disable `tun_wg_0` in pfSense; verify traffic continues via `tun_wg_1`.
2. [ ] **Kill-Switch Works:** Disable both VPN tunnels; verify `192.168.1.150` loses all internet access.
3. [ ] **Snapshots Exist:** Run `zfs list -t snapshot` and ensure your datasets have recent recovery points.
4. [ ] **Restore Test:** Attempt to restore a single file from a ZFS snapshot to `/tmp` to ensure data integrity.

---

**Knowledge Base References:**

- **[pfSense Networking and Routing](../knowledge-base/pfsense/networking-and-routing.md)**
- **[Proxmox Infrastructure Setup](../knowledge-base/proxmox/infrastructure-setup.md)**
- **[Privileged vs Unprivileged LXCs](../knowledge-base/proxmox/privileged-vs-unprivileged-lxcs.md)**

Proceed to the next file:
-> **[(10) Maintenance and Scaling Guide](./10-maintenance-and-scaling-guide.md)**
