#!/usr/bin/env python3
"""Patch the generated Synapse homeserver.yaml for Postgres + reverse-proxy + public_baseurl.

Runs INSIDE CT171 (paths are the CT-local /config bind mount, NOT the host path — the
nested ZFS child datasets are shadowed by the non-recursive LXC bind, so editing via the
host /mnt/flash/docker/synapse/synapse path hits an unused copy; see docs/proxmox).

Order of operations for a fresh Synapse build:
  1. docker compose run --rm synapse generate   # creates /config/synapse/homeserver.yaml + signing key
  2. copy this file into CT171 and run it (python3 configure_synapse.py)
  3. docker compose up -d

Generates the Postgres password on-box, writes it to both /config/.env and homeserver.yaml,
and prints no secrets. Asserts each expected block so it fails loudly rather than silently
corrupting the config.
"""
import secrets, os

BASE = "/config"                               # runs INSIDE CT171
HS   = BASE + "/synapse/homeserver.yaml"       # /config/synapse/homeserver.yaml
ENV  = BASE + "/.env"                           # /config/.env (consumed by docker-compose.yml)

pw = secrets.token_urlsafe(32)

# 1. compose secret (CT /config/.env), 600
with open(ENV, "w") as f:
    f.write("POSTGRES_PASSWORD=%s\n" % pw)
os.chmod(ENV, 0o600)

# 2. patch homeserver.yaml
with open(HS) as f:
    s = f.read()

old_db = "  name: sqlite3\n  args:\n    database: /data/homeserver.db\n"
new_db = ('  name: psycopg2\n  args:\n    user: synapse\n    password: "%s"\n'
          '    database: synapse\n    host: postgres\n    port: 5432\n'
          '    cp_min: 5\n    cp_max: 10\n') % pw
assert old_db in s, "sqlite database block not found as expected"
s = s.replace(old_db, new_db, 1)

old_listener = "  - port: 8008\n"
new_listener = "  - port: 8008\n    bind_addresses: ['0.0.0.0']\n    x_forwarded: true\n"
assert old_listener in s, "listener 'port: 8008' line not found"
s = s.replace(old_listener, new_listener, 1)

old_fed = "      - federation\n"   # client-only on 8008; federation stays off
assert old_fed in s, "federation resource line not found"
s = s.replace(old_fed, "", 1)

if "public_baseurl" not in s:
    if not s.endswith("\n"):
        s += "\n"
    s += "public_baseurl: https://matrix.ryankennedy.dev/\n"

with open(HS, "w") as f:
    f.write(s)

print("OK: /config/.env written (600); homeserver.yaml patched -> "
      "psycopg2, bind 0.0.0.0, x_forwarded, client-only listener, public_baseurl")
