# 07 — Infrastructure Stack (CT100)

This document covers the deployment of the "Control Plane" for your homelab. Located in the Infrastructure LXC (`ct100`), these services provide the ingress (Reverse Proxy), orchestration (Komodo), and data storage (MongoDB) required for the rest of the ecosystem to function.

---

## I. Stack Definition and Storage

All services in this LXC are managed via a single Docker Compose file. This ensures that the entire infrastructure state is captured in one human-readable document.

- **Working Directory:** `/config`
  - *Note: As defined in **[The Privileged LXC Pattern](./05-the-privileged-lxc-pattern.md)**, this directory is a ZFS bind-mount from the host's `flash` pool, optimized with a 16K recordsize.*
- **File:** `/config/docker-compose.yml`

---

## II. Nginx Proxy Manager (NPM)

NPM acts as the front door for your lab. It handles SSL termination via Let's Encrypt and routes incoming traffic based on hostnames.

- **Role:** Ingress and SSL management.
- **Ports:**
  - `80` (HTTP) & `443` (HTTPS): Public traffic.
  - `81`: Management Web UI.
- **Volumes:**
  - `./npm/data:/data`
  - `./npm/letsencrypt:/etc/letsencrypt`
- **Recommended Image:** [LinuxServer.io](https://www.linuxserver.io/) provides highly stable, community-trusted images that align with our UID/GID 1000 standard.

---

## III. Komodo Core and MongoDB

Komodo is the management layer that monitors your containers and handles deployments. It requires MongoDB to store its operational state.

- **Komodo Core:**
  - **Port:** `9120`.
  - **Volumes:** `./komodo:/data`.
- **MongoDB:**
  - **Role:** Backend database for Komodo.
  - **Volumes:** `./mongo:/data/db`.
  - **Note:** This service is kept internal to the Docker network and is not exposed to the LAN.

---

## IV. Deployment Workflow

Once the `docker-compose.yml` is populated, the stack is brought up as a single unit.

1. **Navigate to the config directory:**
   `cd /config`
2. **Pull and Start:**
   `docker compose up -d`
3. **Set Ownership:**
   `chown -R 1000:1000 /config`
   - *Rationale:* Even though we run as root inside the privileged LXC, we manually enforce UID/GID 1000 to ensure the ZFS host can manage snapshots and backups without permission conflicts.

---

## V. Verification and First Steps

Confirm the services are healthy before moving on to the media stack.

- **NPM Check:** Navigate to `http://192.168.1.100:81`.
- **Komodo Check:** Navigate to `http://192.168.1.100:9120`.
- **Log Verification:**
   `docker compose logs -f`
  - Look for successful database connections and Nginx startup messages.

---

**Knowledge Base References:**

- **[pfSense Networking and Routing](../knowledge-base/pfsense/networking-and-routing.md)**
- **[pfSense DNS and Security](../knowledge-base/pfsense/dns-and-security.md)**
- **[Privileged vs Unprivileged LXCs](../knowledge-base/proxmox/privileged-vs-unprivileged-lxcs.md)**

Proceed to the next file:
-> **[(08) Servarr Stack](./08-servarr-stack.md)**
