# Synapse / Matrix Homeserver (P001)

The self-hosted Matrix homeserver that backs the OpenClaw two-agent loop (architect ↔ main).
This page is the operational record for the build: what runs where, how it was wired, the
non-obvious traps, and the routine operations (redeploy, snapshot/restore).

- **server_name:** `matrix.ryankennedy.dev` (permanent — baked into the signing key and every
  user/room ID, cannot be changed later without rebuilding the server)
- **Federation:** OFF. **Open registration:** OFF.
- **Access:** PUBLIC. Ports 80/443 are NAT-forwarded WAN → NPM. Reachable on-net, over
  WireGuard, and from the internet.

---

## Architecture

```
client (Element)  ──►  matrix.ryankennedy.dev
                         │
        split-horizon DNS resolves the name differently by vantage point:
          • on-net / WireGuard:  pfSense host override → 192.168.1.110 (NPM)   (avoids hairpin/NAT-reflection)
          • internet:            DigitalOcean DNS → home WAN → NAT 80/443 → 192.168.1.110 (NPM)
                         │
                         ▼
   NPM (CT110, 192.168.1.110)  ── terminates TLS (Let's Encrypt, DNS-01 via DigitalOcean) ──┐
                         │  proxy host: matrix.ryankennedy.dev → http://192.168.1.171:8008  │
                         ▼                                                                    │
   Synapse (CT171, 192.168.1.171:8008)  ◄───────────────────────────────────────────────────┘
        ├─ synapse        (matrixdotorg/synapse:latest — see "image" note)
        └─ synapse-db      (postgres:16, C-locale)
```

Convention in this lab: **CT id == last octet of the IP.**

| Role    | CT  | IP             | Sizing            | Stack datasets        |
|---------|-----|----------------|-------------------|-----------------------|
| NPM     | 110 | 192.168.1.110  | 1 vCPU / 1G / 8G  | `npm`                 |
| Synapse | 171 | 192.168.1.171  | 2 vCPU / 4G / 20G | `postgres`, `synapse` |

Both are privileged Debian 13 CTs provisioned by the `proxmox_lxc_docker_host` Ansible role
(the "baseline": Docker + Komodo Periphery + ZFS datasets + `/config` bind mount).

---

## Repo artifacts

| File | Purpose |
|------|---------|
| `config/proxmox/ansible/playbooks/provision_npm.yml`     | provision CT110 via the baseline role |
| `config/proxmox/ansible/playbooks/provision_synapse.yml` | provision CT171 via the baseline role |
| `config/proxmox/npm/docker-compose.yml`                  | NPM stack |
| `config/proxmox/synapse/docker-compose.yml`              | Synapse + Postgres stack |
| `config/proxmox/synapse/configure_synapse.py`            | one-shot homeserver.yaml patcher (runs INSIDE CT171) |
| `config/proxmox/ansible/playbooks/deploy_npm_stack.yml`     | redeploy NPM compose |
| `config/proxmox/ansible/playbooks/deploy_synapse_stack.yml` | redeploy Synapse compose |

---

## Build sequence (how it was stood up)

**S1 — NPM (CT110).** `ansible-playbook provision_npm.yml` → `deploy_npm_stack.yml`. In the NPM
admin UI (`http://192.168.1.110:81`) add a Let's Encrypt cert for `matrix.ryankennedy.dev` using
the **DNS-01** challenge with a DigitalOcean API token (domain-scoped). DNS-01 is required because
we don't want to expose port 80 to the ACME HTTP challenge and the cert can be issued before any
public routing exists.

**S2 — Synapse (CT171).** `ansible-playbook provision_synapse.yml`
(`app_datasets: [postgres, synapse]`). Then, first-time only:

```bash
# inside CT171 (or via: pct exec 171 -- bash -lc '...')
cd /config
# 1. generate the default config + signing key
docker compose run --rm \
  -e SYNAPSE_SERVER_NAME=matrix.ryankennedy.dev \
  -e SYNAPSE_REPORT_STATS=no \
  synapse generate
# 2. patch it for Postgres + reverse proxy (see configure_synapse.py header)
python3 /config/configure_synapse.py
# 3. bring the stack up
docker compose up -d
```

`configure_synapse.py` generates the Postgres password on-box, writes it to `/config/.env` (600)
and into `homeserver.yaml`, switches the DB from sqlite → psycopg2, binds the client listener to
`0.0.0.0` with `x_forwarded: true`, strips `federation` from the listener resources (client-only),
and appends `public_baseurl`. It asserts each block so it fails loudly rather than corrupting the
file.

**Back up the signing key off-box immediately** — it is unrecoverable and defines server identity.
It lives at `~/homelab-secrets/matrix.ryankennedy.dev.signing.key` on the Mac (also belongs in a
password manager).

**S3 — Wire.** pfSense host override `matrix.ryankennedy.dev → 192.168.1.110`; NPM proxy host
`matrix.ryankennedy.dev → http://192.168.1.171:8008` (websockets on, Force SSL,
`client_max_body_size 50M`).

**S4 — Accounts.** `register_new_matrix_user` (shared secret): `@ryan` (admin), `@openclaw` and
`@architect` (non-admin, for the agent loop). Registration stays closed. Bot passwords are in
`~/homelab-secrets/matrix-bot-creds.txt`.

**Verify:** `https://matrix.ryankennedy.dev/_matrix/client/versions` returns JSON over valid TLS;
`/.well-known/matrix/client` advertises the homeserver. Element send/receive both directions, on
desktop + phone, on-net and over WireGuard.

---

## Gotchas (the non-obvious stuff)

### Nested ZFS dataset + non-recursive LXC bind = shadowed child datasets
The baseline role creates `flash/docker/<stack>` **and** a child dataset per app
(`flash/docker/<stack>/<app>`). But the LXC bind mount maps only the **parent**
(`flash/docker/synapse → /config`) and it is **non-recursive**. So when Docker writes to
`/config/postgres` and `/config/synapse`, the bytes land in *directories inside the parent
dataset*, not in the child datasets. The child datasets (`flash/docker/synapse/postgres`,
`flash/docker/synapse/synapse`) sit empty and unused.

Consequences:
- **Edit Synapse config from INSIDE the CT** (`/config/...`), never via the host path
  `/mnt/flash/docker/synapse/synapse/...` — that path is the shadowed, unused child dataset.
  (This is why `configure_synapse.py` runs in the container, not on the host.)
- **The snapshot that matters is the parent** `flash/docker/synapse`. (Affects servarr too.)
- Why `flash/docker/synapse/synapse`? The pattern is `<stack>/<app>`; this stack is named
  `synapse` and one of its apps is also `synapse` (the other is `postgres`), so the path reads
  doubled. Cosmetic — same pattern as `flash/docker/servarr/sonarr`.
- *Baseline-role follow-up:* either rbind (recursive) the mount or stop creating child datasets.

### `pct snapshot` is unavailable on bind-mount CTs → use ZFS snapshots
`pct snapshot` refuses ("snapshot feature is not available") because the `/config` bind mount is
not a Proxmox-managed volume. Snapshot at the ZFS layer instead. True for **every** bind-mount CT.

```bash
# rootfs revert point (taken right after baseline, before the app stack)
zfs snapshot flash/vms/subvol-171-disk-0@baseline-clean
# app-data revert point (recursive captures the empty children harmlessly)
zfs snapshot -r flash/docker/synapse@p001-deployed-2026-06-22
```

### Synapse image — use the Element HQ image, not matrixdotorg
Synapse maintenance moved from the Matrix.org Foundation to Element, and the canonical image
moved with it: **`ghcr.io/element-hq/synapse`** (the old `matrixdotorg/synapse` is deprecated).
The two are config-compatible, so switching is just a re-pull + recreate — no regenerate, no DB
change. This stack runs the Element HQ image.

### iOS "Local Network" permission prompt
On the home network, the pfSense host override resolves `matrix.ryankennedy.dev` to the **LAN IP**
`192.168.1.110` (split-horizon, to avoid hairpinning). iOS 14+ requires apps to be granted the
**Local Network** privacy permission before they can reach LAN addresses, so Element prompts for it
on first on-net connect. Allow it. On cellular the name resolves to the public IP, so no prompt
there — this is expected, not a misconfiguration.

### Postgres locale
Synapse requires `C` collation/ctype. The compose sets
`POSTGRES_INITDB_ARGS: "--encoding=UTF8 --lc-collate=C --lc-ctype=C"`. This only applies on first
init of an empty data dir — getting it wrong means re-initializing the database.

---

## Routine operations

**Redeploy the compose (after editing the compose file in the repo):**
```bash
cd config/proxmox/ansible
ansible-playbook playbooks/deploy_synapse_stack.yml   # idempotent; requires /config/.env to exist
```

**Confirm Postgres is the backing store (not sqlite):**
```bash
pct exec 171 -- docker exec synapse-db psql -U synapse -d synapse -c '\dt' | head
# real tables owned by 'synapse' = good
```

**Register another user:**
```bash
pct exec 171 -- docker exec synapse \
  register_new_matrix_user -c /data/homeserver.yaml --no-admin http://localhost:8008
```

**Restore app data from snapshot** (stop the stack first):
```bash
pct exec 171 -- docker compose -f /config/docker-compose.yml down
zfs rollback flash/docker/synapse@p001-deployed-2026-06-22
pct exec 171 -- docker compose -f /config/docker-compose.yml up -d
```

---

## Secrets (NOT in the repo)

| Secret | Location |
|--------|----------|
| Signing key (unrecoverable server identity) | `~/homelab-secrets/matrix.ryankennedy.dev.signing.key` + password manager |
| Bot passwords (`@openclaw`, `@architect`)   | `~/homelab-secrets/matrix-bot-creds.txt` |
| Postgres password                            | CT171 `/config/.env` (600); also literal in `homeserver.yaml` |
| DigitalOcean API token (DNS-01)              | stored in NPM's cert config (domain-scoped token) |
