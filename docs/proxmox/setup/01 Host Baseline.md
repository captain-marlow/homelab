# Host Baseline

## I. Host Identity - pve01

This guide assumes that the host has the following values:

- Proxmox VE `9.1.4`
- host name `pve01`
- Management IP `192.168.1.19/24`
- Gateway/DNS `192.168.1.1`

The networking settings should match the static DHCP reservation you've configured in your firewall. If you're following the [pfSense setup](../pfsense/01-base-and-vpn.md), `192.168.1.19` was already reserved for the Proxmox host.

## II. Installation

Boot from the standard Proxmox VE 9.x ISO and install onto your drives of choice. For this guide, we're using two 500GB SATA SSDs as a ZFS mirror (RAID1). The installer is a graphical wizard. It will ask for a target disk, network settings, and a root password. Select the ZFS (RAID1) filesystem option and choose both SATA drives as the mirror pair (or whatever is proper for your system). See [PVE01 Hardware](../hardware/pve01.md) for the full drive inventory of the main node's hardware.

Using SATA for the OS is deliberate. It preserves all four high-speed NVMe M.2 slots for the ZFS data pools (`flash` and `tank`) that we create in the next step. The OS drive doesn't need NVMe speeds. It just handles boot, system logs, and the Proxmox database.

One the installation is complete, visit the host's management IP on port `8006`: `http://192.168.1.19:8006`

## II. Switch to the No-Subscription Repositories

A fresh Proxmox install usually enables the enterprise repository. In a normal homelab that should be disabled and replaced with the no-subscription repository before the first real update.

In the GUI: `pve01` -> **Repositories** -> disable `pve-enterprise` -> **Add** -> **No-Subscription**. Then go to **Updates**, click **Refresh**, and then **Upgrade**.

After the upgrade finishes, verify the host version:

```bash
pveversion
```

For this lab the expected baseline is Proxmox VE `9.1.4`.

## IV. User Setup

Create a standard admin user on the host. This user serves double duty; it's your login for day-to-day SSH management, and it anchors the UID 1000 permission model that flows through the entire stack.

> **Knowledge Base**: For more on why UID 1000 matters and how it flows through the entire stack, see [Infrastructure Setup — The UID/GID 1000 Standard](../knowledge-base/infrastructure-setup.md#ii-the-uidgid-1000-standard).

```bash
adduser ryan
usermod -aG sudo ryan
```

Verify the ID:

```bash
id ryan
# Expected: uid=1000(ryan) gid=1000(ryan) ...
```

The first non-root user on a Debian system is assigned UID 1000 by default, which is exactly what we want. This same UID will be used inside every LXC and every Docker container, creating a single, consistent ownership identity across the whole lab. When qBittorrent downloads a file, Sonarr moves it, and Jellyfin serves it, they all do so as UID 1000. No permission conflicts at any handoff point.

Then add this user to Proxmox so you can log into the web UI without using root:

1. Go to **Datacenter → Permissions → Users → Add**.
2. Fill in the **User name** field with `ryan`.
3. Set **Realm** to `Linux PAM standard authentication`. This means Proxmox authenticates against the host's Linux user database — same user, same password as SSH. The other option, `Proxmox VE authentication server`, creates a Proxmox-only account that doesn't exist at the OS level. Since we need a user that works for both the web UI and shell access, PAM is the right choice.
4. Click **Add** to create the user.

Now grant the user administrative privileges:

1. Go to **Datacenter → Permissions → Add → User Permission**.
2. Set **Path** to `/` (the root of the Proxmox object tree. This covers all nodes, storage, and containers).
3. Set **User** to `ryan@pam`.
4. Set **Role** to `Administrator`.
5. Click **Add**.

---
Proceed to the next file:

-> [02 — Storage and ZFS Layout](./02-storage-and-zfs-layout.md)
