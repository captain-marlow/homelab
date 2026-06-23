## Common Operational Workflows

This document collects the routine, repeatable operations you will perform while running this homelab. These are not one-time setup steps; they are the things you do _after_ the system exists.

The goal is to avoid re-deriving procedures from memory or reading multiple documents when making small changes.

---

## Add a New Container to an Existing Stack

Example: adding a new service (e.g. `lazylibrarian`) to the Servarr stack.

1. Edit the stack’s compose file on the control node:
    - `pve01/servarr/docker-compose.yml`
2. Define:
    - Image
    - Ports
    - Volumes (only bind what is required)
    - `PUID=1000`, `PGID=1000`, and `UMASK` where supported
3. Commit the change to Git.
4. Deploy using Komodo **or** manually:
```bash
docker compose pull
docker compose up -d
```
1. Verify:
```bash
docker ps
docker logs <container>
```

No Proxmox or ZFS changes are required unless new storage paths are introduced.

---

## Update Containers Safely

Routine image updates should not require stack teardown.

From inside the LXC:

```bash
docker compose pull
docker compose up -d
```

Notes:

- Containers restart in-place
- Volumes and bind mounts are preserved
- Data integrity depends on correct permissions, not container restarts

Avoid `docker compose down` unless you need a full reset.

---

## Restart One Service vs the Whole Stack

Restart a single container:

```bash
docker restart <container>
```

Restart an entire stack:

```bash
docker compose restart
```

Use stack-wide restarts sparingly; most issues are isolated to a single service.

---

## Add a New ZFS Dataset

Used when introducing new persistent data.

Example:

```bash
zfs create flash/docker/new-app \
  -o recordsize=16K \
  -o mountpoint=/mnt/flash/docker/new-app
```

Then:

```bash
chown -R 1000:1000 /mnt/flash/docker/new-app
chmod -R 2775 /mnt/flash/docker/new-app
```

The dataset can now be bind-mounted into an LXC.

---

## Bind-Mount a Dataset into an Existing LXC

Bind mounts are managed at the Proxmox level.

Example:

```bash
pct set 150 -mp1 /mnt/flash/docker/new-app,mp=/config/new-app
pct reboot 150
```

Important:

- LXC **must** be rebooted for new mounts to appear
- The mount path inside the LXC must already exist or be created

---

## Fix Permissions Issues

Symptoms:

- Container can read but not write
- Files owned by `root:root`

Fix:

```bash
chown -R 1000:1000 <path>
chmod -R 2775 <path>
```

Ensure containers use:

- `PUID=1000`
- `PGID=1000`
- `UMASK=002`

Avoid running containers as root unless required.

---

## Change a Bind Mount Path

1. Stop the container(s) using the path
2. Update Proxmox mount:
```bash
pct set <CTID> -mpX <new-host-path>,mp=<ct-path>
pct reboot <CTID>
```
1. Update compose volumes if needed
2. Restart containers    

---

## Verify System State

Quick health checks:

```bash
pct list
zfs list
docker ps
ss -lntp
```

Confirm:

- Expected LXCs are running
- Datasets are mounted
- Containers are healthy

---

## Next

**Next:** operations/troubleshooting.md