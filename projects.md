# Homelab — Projects

*The master list, in three sections: **queue** (active + todo, in order), **deferred** (real projects not yet scheduled), **completed** (the record). **Order lives only in the queue line** — reorder freely. Rows point at the relevant `docs/<subject>/` for detail. The order is a default, not a hard rule — but where one project genuinely needs another first, that's noted.*

**Last updated:** 2026-06-22

Status values: `active` · `queued` · `deferred` · `done` · `idea`

---

## Queue (active + todo)

**Order — edit this line to reorder:** `P002 → P003 → P004 → P005 → P006`

| ID | Project | Subject | Status | Depends on | Detail |
|----|---------|---------|--------|------------|--------|
| P002 | Matrix plugin + single-bot proof (`@openclaw`) | openclaw/matrix | active | P001 | docs/openclaw |
| P003 | Architect agent + doc repo wiring (read-only, Opus) | openclaw/matrix | queued | — (verified after P002) | docs/openclaw, agents/architect |
| P004 | Two-agent loop (architect ↔ main ↔ you, mention-gated) | openclaw/matrix | queued | P001,P002,P003 | docs/openclaw |
| P005 | Ollama LXC (CPU/RAM; hosts embeddings once proven → fixes semantic memory) | ollama | queued | — (after Matrix track) | docs/ollama |
| P006 | Hermes on Mac (standalone → repo integration → OC bridge) | hermes | queued | — | docs/hermes |

---

## Deferred (real projects, not yet scheduled)

| ID | Project | Subject | Status | Note |
|----|---------|---------|--------|------|
| D001 | Gateway-token rotation + scrub retained backups | openclaw | deferred | matched closing step to same-value relocation; low exposure |
| D002 | Phase 5 `.env` work (re-home Telegram token; drop Google web-search `.env` dup) | openclaw | deferred | control-channel token last, one at a time |
| D003 | Proxmox maintenance agent (on Mac/Hermes, SSH-direct, read/propose-first) | proxmox | queued | depends on Hermes; stays off Proxmox by principle |
| D004 | Local Whisper (replaces paid Whisper key) | proxmox | queued | deployed last, via the Proxmox agent |
| D005 | Semantic dispatcher skill (manual routing until then) | openclaw | idea | build once there's a mixed task list to route |
| D006 | Consolidate old Proxmox notes into docs/proxmox | proxmox | queued | ongoing compilation |

---

## Completed

| ID   | Project                                                                                       | Subject  | Status | Detail                       |
| ---- | --------------------------------------------------------------------------------------------- | -------- | ------ | ---------------------------- |
| C001 | Failover & auth hardening (3-deep cross-provider chain, durable Anthropic token)              | openclaw | done   | docs/openclaw/knowledge-base |
| C002 | Step 1 — finish OpenClaw config (memory split, routing policy, hardening, SecretRef, pruning) | openclaw | done   | docs/openclaw/knowledge-base |
| P000 | Migrate repo to category-first layout (planning at root; config/ docs/ agents/)              | repo     | done   | README.md; commit b0e1e57    |
| P001 | Synapse homeserver on own LXC (CT171; Postgres; NPM/TLS; public, federation off)             | openclaw/matrix | done | docs/proxmox/synapse-matrix.md |

---

## Notes on ordering

- The Matrix track (P001–P004) runs **before** Ollama (P005) on purpose: the architect loop is used to plan later steps, so it compounds.
- Matrix internal order is a real dependency chain (Synapse → plugin → architect → loop), not just a preference.
- Most cross-subject items (pfSense rules, note consolidation) have no hard dependency and can slot anywhere.
