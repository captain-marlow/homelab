# 06 — Ansible Orchestration

This document covers the automation of your homelab infrastructure. We use Ansible to move from the manual patterns defined in the previous steps to a reproducible, "Infrastructure-as-Code" model. This ensures that any LXC or Docker host can be rebuilt identically in minutes.

---

## I. Control Node Setup (macOS)

Your macOS workstation acts as the "Control Node." It manages the state of the Proxmox host and LXCs over SSH.

- **Ansible Installation:** Install via Homebrew.
  - `brew install ansible`
- **SSH Key Infrastructure:** - Ensure your public key (`~/.ssh/id_rsa.pub`) is seeded onto the Proxmox host and any "Gold Image" templates.
  - *Rationale:* Ansible relies on passwordless SSH to execute tasks at scale without manual intervention.

---

## II. Inventory Management (hosts.ini)

The inventory file is the "Source of Truth" for your network. It maps hostnames to IP addresses and groups them by their role.

- **File Path:** `ansible/inventory/hosts.ini`
- **Structure:**
  - **[proxmox]:** `pve01 ansible_host=192.168.1.19`
  - **[infrastructure]:** `infrastructure ansible_host=192.168.1.100`
  - **[servarr]:** `servarr ansible_host=192.168.1.150`
- **Technical Reference:** For more on how we organize these hosts, see **[Proxmox Infrastructure Setup](../knowledge-base/proxmox/infrastructure-setup.md)**.

---

## III. Variable Configuration (group_vars)

Variables allow us to define standard settings (like the UID 1000 user) once and apply them to every container.

- **File Path:** `ansible/inventory/group_vars/proxmox.yml`
- **Key Variables:**
  - **ansible_user:** `ryan` (The standard UID 1000 user).
  - **docker_version:** `latest`.
  - **zfs_mount_base:** `/mnt/flash/docker`.
- **Rationale:** By centralizing variables, we ensure that every LXC created by Ansible follows the **[Privileged LXC Pattern](./05-the-privileged-lxc-pattern.md)** exactly.

---

## IV. Provisioning Playbooks

We use specialized playbooks to handle the lifecycle of each service group.

- **Provision Infrastructure (CT100):**
  - **Command:** `ansible-playbook -i inventory/hosts.ini playbooks/provision_infrastructure.yml`
  - **Action:** Creates the LXC, installs Docker, and prepares the `flash` dataset mounts.
- **Provision Servarr (CT150):**
  - **Command:** `ansible-playbook -i inventory/hosts.ini playbooks/provision_servarr.yml`
  - **Action:** Sets up the media stack container and attaches the bulk `tank` dataset.
- **Note on Roles:** Each playbook utilizes the `proxmox_lxc_docker_host` role to ensure a consistent Docker runtime environment.

---

## V. Post-Provisioning Verification

Once a playbook completes, verify the state of the new Docker host.

- **Ping Test:** `ansible all -m ping -i inventory/hosts.ini`
- **Docker Check:** SSH into the new LXC and run `docker info`.
  - *Expected Result:* You should see the **[LinuxServer.io](https://www.linuxserver.io/)** recommended `fuse-overlayfs` driver or similar stable runtime active.

---

**Knowledge Base References:**

- **[Proxmox Infrastructure Setup](../knowledge-base/proxmox/infrastructure-setup.md)**
- **[Privileged vs Unprivileged LXCs](../knowledge-base/proxmox/privileged-vs-unprivileged-lxcs.md)**

Proceed to the next file:
-> **[Infrastructure Stack (CT100)](./07-infrastructure-stack.md)**
