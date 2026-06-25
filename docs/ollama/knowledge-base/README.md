# Ollama — Knowledge Base

**Status: stub (P008, 2026-06-25). No entries yet.**

Reference notes and runbooks for the Ollama LXC tier (CT172).

Add notes here as operational knowledge accumulates.

---

## Quick reference

- **LXC:** CT172 (`192.168.1.172`) — CPU-only Docker host (same `proxmox_lxc_docker_host` Ansible role).
- **Model:** `nomic-embed-text` (768-dim) — backs OpenClaw semantic memory.
- **Access:** LAN-only (port bound to LXC IP, no pfSense NAT; Ollama is auth-less).
- **Blobs:** persist on ZFS `flash` pool.
- **Performance note:** Set cores ≥ 16 to avoid E-core scheduling (4 cores → ~7 s/embed; 16 cores → ~0.3 s/embed).

See `docs/ollama/ollama-tier.md` for the full setup record.
