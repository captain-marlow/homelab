# 05 — The Privileged LXC Pattern

This document defines the "Gold Standard" for creating Linux Containers (LXCs) that will serve as Docker hosts. We utilize **Privileged LXCs** to simplify bind-mount permissions and ensure a seamless hand-off between the ZFS host and the application layer.

---

## I. Container Creation Baseline

We use a standard template to ensure all Docker hosts have the same library versions and behavior.

- **Recommended Template:** `debian-13-standard` or `turnkey-core`.
- **Compute Resources:**
  - **Cores:** 2 (minimum)
  - **Memory:** 4096MB (standard for Docker hosts)
  - **Storage (Rootfs):** 8GB - 20GB on the `vms` storage (SSD Mirror).
- **Network Assignment:**
  - **Bridge:** `vmbr0`
  - **Gateway:** `192.168.1.1` (pfSense)
  - **DNS:** `192.168.1.1` (Following the **[pfSense Hardened DNS](./02-pfsense-hardened-dns.md)** logic)

---

## II. Enabling Docker Features

Standard LXCs lack the kernel permissions required to run a container engine. These "Features" must be enabled in the Proxmox UI under **[LXC] -> Options -> Features**.

- **Nesting:** `Enabled` (Allows Docker to run its own child containers inside the LXC).
- **Keyctl:** `Enabled` (Required for Docker's credential management and certain image layers).
- **FUSE:** `Optional` (Only required if you plan to use Rclone/MergerFS inside the LXC).

---

## III. Standardizing the User (UID 1000)

To avoid "Permission Hell," we ensure the user inside the LXC matches the UID of the data on the ZFS host (UID 1000).

- **Phase A: Create the User**
  - `adduser ryan` (Follow prompts, set password).
- **Phase B: Grant Sudo Access**
  - `usermod -aG sudo ryan`
- **Phase C: Verify ID**
  - Run `id ryan` and confirm it shows `uid=1000(ryan) gid=1000(ryan)`.
  - *Rationale:* Because the LXC is **Privileged**, a file owned by UID 1000 on the Proxmox host will be immediately writable by this user inside the container without any complex mapping.

---

## IV. Binding the ZFS Datasets

We now connect the optimized storage created in **[ZFS Performance Tuning](./04-zfs-performance-tuning.md)** to the LXC. This must be done via the Proxmox CLI on the host (`pve01`).

### Phase A: Mapping Application Configs (Flash)

For the Infrastructure LXC (CT100), mount the high-IOPS dataset:

- `pct set 100 -mp0 /mnt/flash/docker/infrastructure,mp=/config`

### Phase B: Mapping Media (Tank)

For the Servarr LXC (CT150), mount the bulk media dataset:

- `pct set 150 -mp0 /mnt/media,mp=/media`

---

## V. Preparing for Ansible

Before we can hand over the lab to automation, the LXC must be reachable via SSH.

- **Phase A: Install SSH**
  - `apt update && apt install openssh-server -y`
- **Phase B: Seed SSH Key**
  - From your macOS workstation: `ssh-copy-id ryan@192.168.1.100`
- **Phase C: Test Sudo**
  - Ensure the user can run `sudo apt update` without a password prompt if you intend to use fully unattended Ansible playbooks.

---

**Knowledge Base References:**

- **[Proxmox Infrastructure Setup](../knowledge-base/proxmox/infrastructure-setup.md)**
- **[Privileged vs Unprivileged LXCs](../knowledge-base/proxmox/lxc-privilege-evolution.md)**

Proceed to the next file:
-> **[Ansible Orchestration](./06-ansible-orchestration.md)**
