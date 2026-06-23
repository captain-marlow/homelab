# Privileged vs Unprivileged LXCs

This document serves as the definitive guide for understanding the architectural choice between privileged and unprivileged containers in your Proxmox environment. It explains why we prioritize **Privileged LXCs** for high-performance media and data stacks.

---

## I. The Core Difference: UID Shifting

The primary technical distinction between the two modes is how the Linux kernel handles **User IDs (UIDs)** and **Group IDs (GIDs)** between the host and the container.

- **Unprivileged LXCs (The Default)**:
  - **Mechanics**: The host maps the container's `root` (UID 0) to a high-range UID on the host (usually UID 100000).
  - **Security**: If a process escapes the container, it finds itself as a "nobody" user on the host with no permissions.
  - **Drawback**: Accessing ZFS bind-mounts requires complex "UID Mapping" in the `.conf` files to allow the host's UID 1000 to see the container's UID 1000.
  
- **Privileged LXCs**:
  - **Mechanics**: UIDs are shared directly. UID 1000 inside the container is exactly UID 1000 on the Proxmox host.
  - **Security**: If a process escapes, it has the same permissions on the host as it did in the container.
  - **Benefit**: ZFS bind-mounts work natively. Permissions are transparent and easily managed via standard `chown` commands.

---

## II. Why We Use Privileged LXCs

For a media automation lab involving ZFS, the benefits of Privileged containers outweigh the security risks for the following reasons:

1. **Native ZFS Performance**: By avoiding the overhead of the UID mapping layer, file system operations remain as fast as local host performance.
2. **Atomic Hardlinks**: As detailed in **[Servarr Stack](../Build-Steps/08-servarr-stack.md)**, hardlinks are essential. Privileged containers ensure that the UID/GID remains consistent across the mount points, preventing "Cross-device link" errors.
3. **Hardware Passthrough**: It is significantly easier to pass through GPU devices (`/dev/dri/renderD128`) for transcoding in Jellyfin when UIDs are not shifted.
4. **Ansible Simplicity**: Automation playbooks can set permissions once on the host, and they are immediately valid for the application service.

---

## III. Security Mitigations

While Privileged containers are theoretically less secure, we mitigate the risk using the following layers:

- **Isolated Network**: These LXCs are gated by pfSense rules.
- **Limited Scope**: We do not run publicly exposed, untrusted code. Only well-known, community-vetted Docker images (e.g., LinuxServer.io).
- **No Host Root**: Application processes inside the Docker containers run as the `ryan` user (UID 1000), not as `root`.

---

## IV. When to Use Unprivileged

You should still consider Unprivileged LXCs for services that:

- Do not require ZFS bind-mounts.
- Are directly exposed to the internet (e.g., a standalone web server).
- Only handle small, internal configuration data that stays within the container's own virtual disk.

---

## V. Converting a Container

If you ever need to change a container's privilege level, Proxmox does not allow a simple toggle. You must:

1. **Backup** the container.
2. **Restore** the container, choosing the new privilege level in the restore dialogue.
3. **Fix Permissions**: If moving to unprivileged, you will likely need to manually re-map your ZFS bind-mount IDs.

---

**Related Documentation:**

- **[Proxmox Infrastructure Setup](../knowledge-base/proxmox/infrastructure-setup.md)**
- **[The Privileged LXC Pattern](../../setup/05-the-privileged-lxc-pattern.md)**
- **[Servarr Stack](../../setup/08-servarr-stack.md)**
