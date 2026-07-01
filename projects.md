# Homelab — Projects

*The master list, in three sections: **queue** (active + todo, in order), **deferred** (real projects not yet scheduled), **completed** (the record). **Order lives only in the queue line;** reorder freely. Rows point at the relevant `docs/<subject>/` for detail. The order is a default, not a hard rule, but where one project genuinely needs another first, that's noted.*

**Last updated:** 2026-07-01 (D012 Phase 3 step 3 — git write path)

Status values: `active` · `queued` · `deferred` · `done` · `idea`

---

## Queue (active + todo)

**Order — edit this line to reorder:** D012, D011

| ID | Project | Subject | Status | Depends on | Detail |
|----|---------|---------|--------|------------|--------|
| D012 | **Omega — Mac OpenClaw executor (Hermes replacement)** — OpenClaw agent on the Mac via `claude-cli` runtime on Ryan's Claude subscription; replaces OpenAI-locked Hermes, gains native buffer/session/reset. Phased, gated; Hermes kept disabled-not-removed as rollback. | openclaw/matrix | active | none | **Priority. Phase 3 in progress:** Phase 2.5 DM path complete; Phase 3 Steps 1–2 done (`gpt-5.5` codex-OAuth fallback verified live; exec posture verified as mention-gated peer executor matching `main`). Step 3 done: omega proved own commit+push under `Omega <omega@ryankennedy.dev>` (auto-pull hook verified). Resume at Step 4: one infra action verified live, then parity. See `docs/openclaw/omega-mac-agent.md`. |
| D011 | Matrix multi-agent routing/gating pass — room-ping behavior, Hermes verbosity, and history-window tuning | matrix/routing | queued | none | **DECIDED 2026-06-28, ready to execute as one Hermes-config pass:** (a) **Room-ping → broadcast to all three.** Architect + OC already fire on a room ping; **add a room-ping trigger to Hermes** to match. Caveat: Hermes will reply context-blind until it has a buffer (see D010). (b) **Quiet Hermes verbosity** — locate + apply the tool-call-streaming setting. (c) Bump OC/architect `historyLimit` **30 → 50**. (d) `textMentioned` tightening: **SKIP** (unconfirmed path; not worth a fragile source patch). OC "gate-jumping" concern: **DROPPED** per Ryan. Root cause for the record: the "OC responding unexpectedly" issue was room-pings in architect's own messages + read-on-trigger receipts — no exotic bug. |
| P011 | Hermes follow-ups & autonomy-scoping — (1) stop/KeepAlive trap documented + corrected (`8cedb28`) ✅; (2) stale-stream timeout: fix identified (`providers.<id>.stale_timeout_seconds ≈ 120–180s` in `config.yaml`), gate config edit when Mac-side ✅; (3) autonomy/approval audit: confirmed safe (`approvals.mode=manual`, `cron_mode=deny`, `destructive_slash_confirm=true`); `--yolo` = one-shot tasks only, never the gateway ✅; (4) division of labor: **Hermes = Proxmox / infra / git steady-state; OpenClaw = router + cross-node recovery executor** — when Hermes is down, OpenClaw SSHes into the Mac to diagnose/recover (proven 2026-06-26: pushed `26219ec`/`8cedb28` via Mac SSH). Scope grows by recovery need, not domain claim. Recovery access is policy-bounded (convention not hard wall, consistent with mention-gating model). CT175→Mac SSH path is Hermes-independent (own key, own route) ✅. **P011 COMPLETE.** | hermes | done | P006 done | `docs/hermes/hermes-mac.md` |

---

## Deferred (real projects, not yet scheduled)

| ID | Project | Subject | Status | Note |
|----|---------|---------|--------|------|
| D001 | Gateway-token rotation + scrub retained backups | OpenClaw | deferred | matched closing step to same-value relocation; low exposure |
| D002 | Phase 5 `.env` work (re-home Telegram token; drop Google web-search `.env` dup) | OpenClaw | deferred | control-channel token last, one at a time |
| D003 | Proxmox maintenance agent (on Mac/Hermes, SSH-direct, read/propose-first) | Proxmox | queued | depends on Hermes; stays off Proxmox by principle |
| D004 | Local Whisper (replaces paid Whisper key) | Proxmox | queued | deployed last, via the Proxmox agent |
| D005 | OpenClaw router expansion + local cheap-generation tier — add small chat model(s) to CT172 (prove on boring tests first), then expand OpenClaw's router so it orchestrates by role: cheap/high-frequency work (heartbeat, classification, routing hints) → local Ollama models; heavy reasoning → cloud (Opus/gpt-5.5/Sonnet); execution (e.g. ansible deploy) → Hermes. Semantic routing can use the P005 embeddings. The embedding model aids *deciding*; a local chat model does the cheap *generating* — distinct roles. | OpenClaw/ollama | deferred | Design validated offline, then deferred because there is no active heartbeat workload yet. See `docs/ollama/heartbeat-hybrid-design.md`. |
| D006 | Consolidate old Proxmox notes into `docs/proxmox` | Proxmox | queued | ongoing compilation; Docker management-strategy now captured in `docs/proxmox/docker-gitops-architecture.md` (D009) |
| D007 | Agent config versioning + backup (architect, OpenClaw, Hermes) | agents | idea | Two halves: (1) **version-control** sanitized identity/config in `agents/<name>/` — architect already there; add `agents/openclaw/` (SOUL + sanitized `openclaw.json`) and `agents/hermes/` (SOUL + sanitized `config.yaml`/`.env.example`), secrets externalized via SecretRef/env (never in repo). (2) **back up the secrets** — `~/.homelab-secrets` (Mac), CT175 `openclaw.json` secrets, CT171 `/config/.env`, Hermes `.env` + Matrix recovery key — to an encrypted off-box store + password manager, with a documented restore. The real gap: no systematic backup of live settings or of `~/.homelab-secrets` itself. Pairs with D001/D002 (rotation) and the agents/ layout. |
| D008 | Local LLM on Vega 64 — build a Vulkan-backed GPU local-generation tier using Vega 64 (8 GB VRAM), Qwen3-8B Q4_K_M as the primary model, quantized KV cache, and context sized to preserve VRAM headroom. This is the GPU evolution of the CPU-only Ollama tier and the performance enabler for a future D005 resume. | ollama/proxmox | deferred | Open scoping question: CT172 passthrough vs. separate/new machine. See `docs/ollama/vega64-gpu-tier.md`. |
| D009 | Proxmox Docker management — GitOps architecture design (Komodo + Ansible two-layer model, pull/GitOps, state-var Periphery, ZFS-backed rebuild safety). Design approved 2026-06-28. Implementation gated on D007 (secrets inventory) for rebuild-safety. | Proxmox | deferred | D007 prerequisite for disposable-LXC guarantee | `docs/proxmox/docker-gitops-architecture.md` |
| D010 | Hermes Matrix history-backfill (passive room buffer) — passive room context analog | hermes/matrix | deferred | **DECIDED 2026-06-28: option (c) — do NOT build the passive-room buffer now.** Hermes stays addressed-only; pill it with context when needed. Keep **(b) upstream-PR to Nous** noted as the preferred future path over a local fork. If ever built, size the buffer to **50** to match the others. |

---

## Completed

| ID   | Project                                                                                       | Subject  | Status | Detail                       |
| ---- | --------------------------------------------------------------------------------------------- | -------- | ------ | ---------------------------- |
| C001 | Failover & auth hardening (3-deep cross-provider chain, durable Anthropic token)              | OpenClaw | done   | `docs/openclaw/knowledge-base` |
| C002 | Step 1 — finish OpenClaw config (memory split, routing policy, hardening, SecretRef, pruning) | OpenClaw | done   | `docs/openclaw/knowledge-base` |
| P000 | Migrate repo to category-first layout (planning at root; config/ docs/ agents/)              | repo     | done   | README.md; commit b0e1e57    |
| P001 | Synapse homeserver on own LXC (CT171; Postgres; NPM/TLS; public, federation off)             | OpenClaw/matrix | done | `docs/proxmox/synapse-matrix.md` |
| P002 | Matrix plugin + single-bot proof (`@openclaw`), E2EE working, per-room session isolation     | OpenClaw/matrix | done | `docs/openclaw/matrix-bot-channel.md` |
| P003 | Architect agent + doc repo wiring (read-only Opus; own Max token; deploy-key repo clone)     | OpenClaw/matrix | done | `docs/openclaw/architect-agent.md` |
| P004 | Two-agent loop (architect ↔ main ↔ you, mention-gated Drafting Table room)                  | OpenClaw/matrix | done | `docs/openclaw/two-agent-loop.md` |
| P005 | Ollama LXC (CPU-only; `nomic-embed-text` → restored OpenClaw semantic memory)                | ollama          | done | `docs/ollama/ollama-tier.md` |
| P006 | Hermes on Mac — standalone + repo integration + Matrix loop (`@hermes` live in Drafting Table, E2EE, mention-gated; Mac-side read-write/git-push executor) | hermes | done | `docs/hermes/hermes-mac.md` |
| P007 | Documentation style guide (`STYLE.md`) + Vale/markdownlint (terminology, headers, formatting, verbosity norms; derived from existing house style). Also covers the architect's response-style spec (shorter, fewer caveats) as a subset. | docs | done | `docs/meta` |
| P008 | Documentation sort pass — bring all docs to `STYLE.md` (markdownlint structure, Vale terminology, em-dash rewrites, Ollama knowledge-base stub). | docs | done | `docs/meta` |
| P009 | Architect read-only web access (`web_fetch`, keyless HTTP GET — verified live) + full-MXID handoff convention in its SOUL | OpenClaw/matrix | done | `docs/openclaw/architect-agent.md` |
| P012 | Per-agent model chain split — `main` → `anthropic/claude-sonnet-4-6` → `openai/gpt-5.5`; `architect` → `anthropic/claude-opus-4-8` → `openai/gpt-5.5`; `agents.defaults.model` documented as inherited base only, not main's effective chain; Gemini confirmed out of all text chains; `MEMORY.md` + `STATE.md` + failover-reference doc updated. | OpenClaw | done | `STATE.md`, `MEMORY.md`, `docs/openclaw/openclaw-failover-reference-2026-06-21.md` |

---

## Notes on ordering

- The Matrix track (P001–P004) was done **before** Ollama (P005) on purpose: the architect loop is used to plan later steps, so it compounds (done 2026-06-23).
- Matrix internal order was a real dependency chain (Synapse → plugin → architect → loop), not just a preference.
- **Hermes (P006) is sequenced before the docs work (P007 → P008):** P008's "apply + push the styled rewrites" step needs the central read-write executor, which is Hermes (the architect is pull-only; OpenClaw write access is deferred). So Hermes must exist before the sort pass. IDs are non-sequential here (P006 = Hermes predates the docs projects); order lives in the queue line.
- **P007 + P008 are a pair:** write `STYLE.md` + stand up the linters, then immediately run every doc through the loop against it. P007's guide is the shared contract both Vale and the architect read.
- P008 reuses the two-agent loop (architect proposes styled rewrites read-only → human gate → **Hermes** applies + pushes) — documentation cleanup is itself a planner→executor task.
- **Git writers (P006 done):** Claude Code and **Hermes** both write to the Mac-side repo now (distinguish by commit author). With Hermes's dedicated identity + write deploy key, repo mutations driven by the loop should be **delegated to Hermes** so authorship/role boundaries stay clear (`@openclaw` should no longer commit via Ryan's Mac clone). The architect's clone (CT175) stays a read-only mirror; refresh all three clones after every push.
- Most cross-subject items (pfSense rules, note consolidation) have no hard dependency and can slot anywhere.
