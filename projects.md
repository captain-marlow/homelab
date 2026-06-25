# Homelab — Projects

*The master list, in three sections: **queue** (active + todo, in order), **deferred** (real projects not yet scheduled), **completed** (the record). **Order lives only in the queue line** — reorder freely. Rows point at the relevant `docs/<subject>/` for detail. The order is a default, not a hard rule — but where one project genuinely needs another first, that's noted.*

**Last updated:** 2026-06-25

Status values: `active` · `queued` · `deferred` · `done` · `idea`

---

## Queue (active + todo)

**Order — edit this line to reorder:** `P008`

| ID | Project | Subject | Status | Depends on | Detail |
|----|---------|---------|--------|------------|--------|
| P008 | Documentation sort pass — bring all docs to `STYLE.md` via the loop (architect audits/proposes → you gate → Hermes applies + pushes; Vale as the mechanical floor). Worklist from P007: (a) markdownlint reflow/hygiene (~390 findings, mostly MD013 line-length and heading/fence blank-line hygiene), (b) Vale terminology fixes (lowercase `openclaw`/`proxmox` in `STATE.md`, `projects.md`, `two-agent-loop.md`), (c) ~92 body-prose em-dashes to revise, (d) `docs/ollama/` missing its `knowledge-base/` subfolder (structural drift, normalize to the README layout). | docs | queued | P004, P006, P007 | docs/meta |

---

## Deferred (real projects, not yet scheduled)

| ID | Project | Subject | Status | Note |
|----|---------|---------|--------|------|
| D001 | Gateway-token rotation + scrub retained backups | openclaw | deferred | matched closing step to same-value relocation; low exposure |
| D002 | Phase 5 `.env` work (re-home Telegram token; drop Google web-search `.env` dup) | openclaw | deferred | control-channel token last, one at a time |
| D003 | Proxmox maintenance agent (on Mac/Hermes, SSH-direct, read/propose-first) | proxmox | queued | depends on Hermes; stays off Proxmox by principle |
| D004 | Local Whisper (replaces paid Whisper key) | proxmox | queued | deployed last, via the Proxmox agent |
| D005 | OpenClaw router expansion + local cheap-generation tier — add small chat model(s) to CT172 (prove on boring tests first), then expand OpenClaw's router so it orchestrates by role: cheap/high-frequency work (heartbeat, classification, routing hints) → local Ollama models; heavy reasoning → cloud (Opus/gpt-5.5/Sonnet); execution (e.g. ansible deploy) → Hermes. Semantic routing can use the P005 embeddings. The embedding model aids *deciding*; a local chat model does the cheap *generating* — distinct roles. | openclaw/ollama | idea | manual routing until then; build once there's a mixed task list to route. Pairs with build-plan Step 3; subsumes the old "semantic dispatcher skill" framing |
| D006 | Consolidate old Proxmox notes into docs/proxmox | proxmox | queued | ongoing compilation |
| D007 | Agent config versioning + backup (architect, OpenClaw, Hermes) | agents | idea | Two halves: (1) **version-control** sanitized identity/config in `agents/<name>/` — architect already there; add `agents/openclaw/` (SOUL + sanitized `openclaw.json`) and `agents/hermes/` (SOUL + sanitized `config.yaml`/`.env.example`), secrets externalized via SecretRef/env (never in repo). (2) **back up the secrets** — `~/.homelab-secrets` (Mac), CT175 `openclaw.json` secrets, CT171 `/config/.env`, Hermes `.env` + Matrix recovery key — to an encrypted off-box store + password manager, with a documented restore. The real gap: no systematic backup of live settings or of `~/.homelab-secrets` itself. Pairs with D001/D002 (rotation) and the agents/ layout. |

---

## Completed

| ID   | Project                                                                                       | Subject  | Status | Detail                       |
| ---- | --------------------------------------------------------------------------------------------- | -------- | ------ | ---------------------------- |
| C001 | Failover & auth hardening (3-deep cross-provider chain, durable Anthropic token)              | openclaw | done   | docs/openclaw/knowledge-base |
| C002 | Step 1 — finish OpenClaw config (memory split, routing policy, hardening, SecretRef, pruning) | openclaw | done   | docs/openclaw/knowledge-base |
| P000 | Migrate repo to category-first layout (planning at root; config/ docs/ agents/)              | repo     | done   | README.md; commit b0e1e57    |
| P001 | Synapse homeserver on own LXC (CT171; Postgres; NPM/TLS; public, federation off)             | openclaw/matrix | done | docs/proxmox/synapse-matrix.md |
| P002 | Matrix plugin + single-bot proof (`@openclaw`), E2EE working, per-room session isolation     | openclaw/matrix | done | docs/openclaw/matrix-bot-channel.md |
| P003 | Architect agent + doc repo wiring (read-only Opus; own Max token; deploy-key repo clone)     | openclaw/matrix | done | docs/openclaw/architect-agent.md |
| P004 | Two-agent loop (architect ↔ main ↔ you, mention-gated Drafting Table room)                  | openclaw/matrix | done | docs/openclaw/two-agent-loop.md |
| P005 | Ollama LXC (CPU-only; `nomic-embed-text` → restored OpenClaw semantic memory)                | ollama          | done | docs/ollama/ollama-tier.md |
| P006 | Hermes on Mac — standalone + repo integration + Matrix loop (`@hermes` live in Drafting Table, E2EE, mention-gated; Mac-side read-write/git-push executor) | hermes | done | docs/hermes/hermes-mac.md |
| P007 | Documentation style guide (`STYLE.md`) + Vale/markdownlint (terminology, headers, formatting, verbosity norms; derived from existing house style). Also covers the architect's response-style spec (shorter, fewer caveats) as a subset. | docs | done | docs/meta |
| P009 | Architect read-only web access (`web_fetch`, keyless HTTP GET — verified live) + full-MXID handoff convention in its SOUL | openclaw/matrix | done | docs/openclaw/architect-agent.md |

---

## Notes on ordering

- The Matrix track (P001–P004) was done **before** Ollama (P005) on purpose: the architect loop is used to plan later steps, so it compounds (done 2026-06-23).
- Matrix internal order was a real dependency chain (Synapse → plugin → architect → loop), not just a preference.
- **Hermes (P006) is sequenced before the docs work (P007 → P008):** P008's "apply + push the styled rewrites" step needs the central read-write executor, which is Hermes (the architect is pull-only; openclaw write access is deferred). So Hermes must exist before the sort pass. IDs are non-sequential here (P006 = Hermes predates the docs projects); order lives in the queue line.
- **P007 + P008 are a pair:** write `STYLE.md` + stand up the linters, then immediately run every doc through the loop against it. P007's guide is the shared contract both Vale and the architect read.
- P008 reuses the two-agent loop (architect proposes styled rewrites read-only → human gate → **Hermes** applies + pushes) — documentation cleanup is itself a planner→executor task.
- **Git writers (P006 done):** Claude Code and **Hermes** both write to the Mac-side repo now (distinguish by commit author). With Hermes's dedicated identity + write deploy key, repo mutations driven by the loop should be **delegated to Hermes** so authorship/role boundaries stay clear (`@openclaw` should no longer commit via Ryan's Mac clone). The architect's clone (CT175) stays a read-only mirror; refresh all three clones after every push.
- Most cross-subject items (pfSense rules, note consolidation) have no hard dependency and can slot anywhere.
