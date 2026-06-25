# Privileged LXC Pattern

This document explains how Linux Containers (LXCs) are used in this homelab, what the difference is between privileged and unprivileged containers, and why this setup deliberately chooses privileged LXCs.

LXCs differ from VMs in that they share the Kernel with the host. This lowers

The short version is that privileged containers keep UID/GID values the same inside the LXC and on the host. That means `ryan:ryan` as `1000:1000` behaves the same across ZFS, the LXC, and the Docker containers running inside it.

`pveam download local debian-13-standard_13.1-2_amd64.tar.zst`

## 2. Standard LXC Settings

Every Docker-host LXC in this repo follows the same baseline unless a later page says otherwise. Use these values as the default mental model for CT100, CT150, and future containers of the same type.

- privileged container
- Debian 13 template from `isos`
- root filesystem on `vms`
- bridge `vmbr0`
- static LAN IP
- gateway `192.168.1.1`
- DNS `192.168.1.1`
- features `nesting=1,keyctl=1`

Those two feature flags matter. `nesting=1` allows container workloads inside the LXC, and `keyctl=1` avoids common Docker and container-runtime issues that appear when the LXC is too locked down.

## 3. Standard Bind Mount Pattern

This lab keeps persistent data on the Proxmox host and bind-mounts it into LXCs. The standard pattern is one `/config` mount per stack, plus `/data` where a workload needs shared media or bulk files.

- CT100: `/mnt/flash/docker/infrastructure` -> `/config`
- CT150: `/mnt/flash/docker/servarr` -> `/config`
- CT150: `/mnt/tank/media` -> `/data`

This is the main reason the storage work came first. Once the host-side paths are stable, the LXC layer becomes very straightforward.

## Docker Host LXCs in This Setup

Two Docker-capable LXCs exist so far:

- **CT100 – `infrastructure`**
  - Komodo Periphery agent
  - Nginx Proxy Manager
  - Supporting infrastructure services
- **CT150 – `servarr`**
  - qbittorrent
  - radarr / sonarr / lidarr / prowlarr
  - Media-related workflows

Each LXC:

- Has Docker Engine + Compose plugin installed
- Uses systemd normally
- Mounts a single `/config` directory backed by ZFS
- Receives additional bind mounts (e.g. `/data`) as needed

## II. Create the Container (CLI)

All LXC creation is done via the command line on the Proxmox host using `pct create`. This approach is more explicit and reproducible than the GUI, and it's what Ansible will automate later in [Step 04](./04-ansible-orchestration.md).

> **Note**: These steps can also be done through the Proxmox web GUI if you prefer — the creation wizard walks through the same parameters. However, the CLI is the canonical method documented here because it's scriptable and leaves no ambiguity about what was set.

### Infrastructure LXC (CT100)

```bash
pct create 100 local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst \
  --hostname infrastructure \
  --cores 2 \
  --memory 4096 \
  --swap 512 \
  --rootfs vms:8 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.100/24,gw=192.168.1.1 \
  --nameserver 192.168.1.1 \
  --features nesting=1,keyctl=1 \
  --unprivileged 0
  --onboot 1
```

### Servarr LXC (CT150)

```bash
pct create 150 local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst \
  --hostname servarr \
  --cores 4 \
  --memory 8192 \
  --swap 1024 \
  --rootfs vms:8 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.150/24,gw=192.168.1.1 \
  --nameserver 192.168.1.1 \
  --features nesting=1,keyctl=1 \
  --ssh-public-keys ~/.ssh/authorized_keys.pub \
  --unprivileged 0 \
  --onboot 1
```

Key flags:

- `--features nesting=1,keyctl=1` enables the kernel permissions Docker needs. **Nesting** allows Docker to create its own child containers inside the LXC. **Keyctl** is required for Docker's credential management and certain image layer operations. These are set at creation time so the container is Docker-ready from the start.
- `--unprivileged 0` creates a privileged container (the default, but explicit here for clarity).
- `--rootfs vms:8` places the 8GB root filesystem on the SATA SSD pool, keeping the NVMe pools free for application data.
