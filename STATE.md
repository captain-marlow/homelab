# Homelab — Current State

*The narrative snapshot of where everything stands right now, a complete overview of the entire homelab cluster. Read this first. For the ordered task list see `projects.md`; for the idea pool see `ideas.md`; for per-subject detail see `docs/<subject>/`.*

**Last updated:** 2026-06-27

---

## Repo

Migrated to the **category-first** layout (`config/` · `docs/` · `agents/`, subject as the namespace inside each). **P000 complete (2026-06-22)**; see `README.md`. The pre-consolidation doc trees (`docs_old/_new/_gpt/_complete`) are kept on disk but untracked, pending D006.

---

## OpenClaw

**Status: daily driver, hardened, documented. Step 1 of the build plan complete.**

- Gateway running on the `openclaw` LXC (Proxmox CT, Debian, static `192.168.1.175`), OpenClaw 2026.6.8.
- **Per-agent model chains (updated 2026-06-27):** model chains are now configured per-agent in `agents.list[].model`, not as a single shared chain. `agents.defaults.model` (`anthropic/claude-sonnet-4-6` → `openai/gpt-5.5`) is only the inherited base for unconfigured agents/surfaces.
  - `main`: primary `anthropic/claude-sonnet-4-6` (claude-cli runtime, `anthropic:default` token) → fallback `openai/gpt-5.5`. No Gemini.
  - `architect`: primary `anthropic/claude-opus-4-8` (claude-cli runtime, `anthropic:default` token) → fallback `openai/gpt-5.5`. No Gemini.
- **(Gemini removed 2026-06-25)** — the `google/gemini-3-flash-preview` 3rd leg was dropped: its metered API key sits on a **0-token free tier** (useless), and the only subscription path (OpenClaw's `google-gemini-cli` OAuth) carries a Google-warned **account-suspension risk**, declined for a personal account. Web search (which was also Gemini-backed) is **disabled** as a result. The dead `google:manual` auth profile was also purged. *(Op note: OpenClaw auth profiles live as JSON blobs in the agent's sqlite — `auth_profile_store`/`auth_profile_state` in `agents/<id>/agent/openclaw-agent.sqlite` — there's no CLI remove; safe removal = stop gateway → back up the db → edit the blob → restart. Useful for D001/D002 rotation.)*
- Anthropic durable token leads its leg; `claude-cli` OAuth demoted to manual-pin fallback.
- `MEMORY.md` is the canonical boot file (durable policy); `OPEN-ISSUES.md` holds transient state.
- Filesystem hardened (`~/.openclaw` → 700); SecretRef migration done (1 accepted plaintext exception: the static Anthropic token, which OpenClaw's SecretRef subsystem structurally can't hold).
- Recovery-notification skill active (closes the promised-but-unmechanized switch-back notice).
- Context pruning TTL tuned 1h→20m; watching peak context and cache-read over the next few large sessions.

**Deferred / watching:**

- Semantic memory **RESTORED (2026-06-24, P005)** — now served by local Ollama embeddings (`nomic-embed-text` on CT172), replacing the dead OpenAI path. `main`'s index = 7 files / 53 chunks; `openclaw memory search` returns real ranked results. Embed latency ~0.3s after the CT172 core bump (4→16). See the Ollama tier section below + `docs/ollama/ollama-tier.md`. (The silent-failure caveat still holds in general: `openclaw memory search` can exit 0 with empty output after an embedding failure — empty ≠ absence.)
- Gateway-token rotation deferred (loopback-only, low exposure) but is the matched closing step to the same-value relocation.
- Anthropic usage stats absent from dashboard post-June-15 — leading theory is a billing change; treated as cosmetic.
- **Web search is off** (was Gemini-backed; both OpenClaw "google" web-search paths hit the Generative Language API). To restore real search, add a **non-Gemini provider** (Tavily / Brave / Exa — actual free tiers) — folded into the architect read-only-web-ingest idea (see `ideas.md`). The dormant `google_websearch_key_file` SecretRef + `plugins.entries.google` were left in place (harmless) for a possible future repoint.

---

## Matrix two-agent loop (architect + main) — COMPLETE

**Status: DONE (2026-06-23) — P001 (Synapse) + P002 (Matrix bot channel) + P003 (architect agent) + P004 (two-agent loop, mention-gated) all complete. The planning loop now runs inside the homelab. Next track: Ollama (P005).**

The current planning loop (Opus planner → human gate → executor) now runs inside the homelab, in a self-hosted Matrix room (**Drafting Table**). Planner = `architect` agent (read-only, Opus); executor = the OpenClaw gateway as `@openclaw`; gate = `@ryan`. Built before Ollama because the loop is used to plan every later step (and already is, having produced a sequenced P005-vs-P006 recommendation in its first live session).

Dependency chain (all done): Synapse homeserver → Matrix plugin + single-bot proof → architect agent + doc repo → two-agent loop.

**Synapse homeserver (P001 — live):** `matrix.ryankennedy.dev` on CT171 (`.171`), Postgres 16 backed, Element HQ image. Reverse-proxied by NPM on CT110 (`.110`) with a Let's Encrypt DNS-01 cert; public (80/443 NAT-forwarded), **federation off**, registration closed. Split-horizon DNS (pfSense host override → `.110` on-net; DigitalOcean → WAN off-net). Verified send/receive on desktop + phone, on-net and over WireGuard. Accounts: `@ryan` (admin), `@openclaw` + `@architect` (non-admin). Secrets (signing key, bot creds) off-box in `~/.homelab-secrets/`. Full record: `docs/proxmox/synapse-matrix.md`.

**Matrix bot channel (P002 — live):** OpenClaw gateway (CT175) wired to Synapse as `@openclaw` via the `@openclaw/matrix@2026.6.8` channel plugin (config-edited directly into `openclaw.json`, since the box CLI is intentionally read-only). Bot reads/responds over Matrix, gated to `@ryan` (`dm.allowFrom`). **E2EE working:** encryption auto-bootstrapped `@openclaw`'s cross-signing + self-verified device; bot decrypts and replies encrypted. `dm.sessionScope=per-room` isolates rooms (so encrypted content can't bleed into unencrypted replies). Encrypted-invite auto-join is finicky → bot is joined into rooms manually (one-time per room; small fixed set). Follow-ups: user-verify `@openclaw` (green shield), back up E2EE recovery key off-box, resolve the pending CLI scope request. Full record: `docs/openclaw/matrix-bot-channel.md`.

**Architect agent (P003 — live):** Second OpenClaw agent (`architect`) on CT175 alongside `main`, the read-only planner half of the loop. Pinned to `anthropic/claude-opus-4-8` on its **own dedicated Max setup-token** (separate auth store from `main`, independently revocable). **Read-only / deny-exec** by tool policy (effective tools `read`/`message`/`web_fetch`/`session_status`, exec denied, `sandbox.workspaceAccess=ro`, `skills:[]`). Proven live. **P009 (2026-06-25) added `web_fetch`:** keyless in-process HTTP GET (a read, not a mutation; not in `group:runtime`, so read-only/deny-exec is intact) so the planner can read docs/repos/forums while planning; verified live (fetched example.com, 200). Its SOUL now also carries the **full-MXID handoff** convention (bare `@name` is inert; use the full MXID to delegate to `@openclaw`/`@hermes`). Reads the homelab repo as its knowledge base: cloned into its workspace via a **read-only GitHub deploy key** (under the `openclaw` user, `github-homelab` SSH alias), refreshed by manual `git pull`. Identity (`IDENTITY/USER/SOUL.md`) authored in the repo at `agents/architect/` and **symlinked** into the workspace root; `BOOTSTRAP.md` removed; no `MEMORY.md` (the repo is its memory). Verified answering on Opus, grounded in the docs. Bound on Matrix in P004. Full record: `docs/openclaw/architect-agent.md`.

**Two-agent loop (P004 — live):** Both bots in one encrypted room (**Drafting Table**, `!FKZTkwAIkROBtdHyCl`) with `@ryan`. `@architect` (account `architect`, Opus) plans; `@openclaw` (account `default`, Sonnet 4.6) executes; `@ryan` gates. **Multi-account migration was additive:** `@openclaw` stayed the implicit top-level `default` account (token + E2EE store untouched); only `accounts.architect` was added (the plugin connects the accounts map *plus* the implicit default, so no relocation was needed). Routing bound via `openclaw agents bind` (no scope wall). **Mention-gated:** `channels.matrix.rooms[<id>]` with `allowBots:"mentions"` + `requireMention:true` (applies to both accounts), `botLoopProtection` on; nothing fires unless `@`-mentioned. **Verified:** architect plans when mentioned, OpenClaw stays silent when not (the brake), both reachable live (closes the deferred gateway-path proof). **Bots CAN trigger each other via the full MXID** (`@openclaw:matrix.ryankennedy.dev`), which OpenClaw converts to a real `m.mentions` pill (`was_mentioned:true`); a bare localpart (`@openclaw`) is inert text. So autonomous planner↔executor handoff works, and `@ryan` isn't strictly required to relay. Brakes are by convention + backstop, not a hard wall: kill-switch = omit the mention, `botLoopProtection` (20/60s), `requireMention:true`, and agent SOUL discipline. `contextVisibility:"all"` lets a triggered bot read the other's message. (Earlier "bots can't auto-trigger" was a full-MXID-vs-localpart misdiagnosis, corrected after live testing.) Fresh session = `/reset` or `/new` in the room. Architect's token was minted via `localhost:8008` on CT171 (`**the public URL rejects password-login (403)**` while token auth works, a finding that also proved the bot creds file is *not* stale). Full record: `docs/openclaw/two-agent-loop.md`.

---

## Ollama local-AI tier (CT172) — COMPLETE

**Status: DONE (2026-06-24) — P005. Local embeddings now back OpenClaw semantic memory; the OpenAI entitlement gap is closed without a paid key.**

A CPU-only Ollama runner on its own LXC (`192.168.1.172`, same `proxmox_lxc_docker_host` Ansible role as the other stacks; Docker + Komodo Periphery). Hosts one embedding model, **`nomic-embed-text`** (768-dim), **LAN-only** (port bound to the LXC IP, no pfSense NAT forward; Ollama is auth-less, so the LAN is the boundary). Model blobs persist on the ZFS `flash` pool.

OpenClaw's `agents.defaults.memorySearch` was repointed `provider: openai → ollama` (first-class provider; hits `/api/embed`; `batch:false`, `fallback:none`), gateway restarted, index force-rebuilt → **7 files / 53 chunks**; `memory search` returns real ranked hits (positive test, empty≠absence). **Perf finding:** first build was ~7s/embed because CT172 had only 4 of the host's 32 threads on a **hybrid P/E-core CPU** (threads likely on E-cores); `pct set 172 -cores 16` dropped embed latency to **~0.3s** (~20–40× faster). GPU deferred; a small local chat model for cheap-task offload is the next use of this tier (separate step). Full record: `docs/ollama/ollama-tier.md`.

---

## Hermes (Mac-side read-write / git-push executor) — P006 COMPLETE

**Status: DONE (2026-06-24/25) — steps a (standalone) + b (repo integration) + c (Matrix loop) all
verified.** Hermes (Nous Research agent) on the Mac is the institutional version of the
read-write/git-push executor role Claude Code plays manually now — a hard dependency for **P008**.
`@hermes` is now a live, E2EE, mention-gated participant in the Drafting Table room beside
`@openclaw`/`@architect`.

- **Standalone (a):** Hermes v0.17.0 on this Intel Mac (CLI; desktop app is ARM-only). Current live
  config is `openai/gpt-5.5` via `provider: openai-codex`, using device-code OAuth against the
  ChatGPT/OpenAI subscription; `model.base_url` is unset. This replaced the failed
  Anthropic-subscription-OAuth path. The old OpenRouter URL was a never-removed Nous default, not an
  intentionally configured routing layer. Migrate-from-OpenClaw skipped — the Mac's `~/.openclaw`
  was a stale March shell (now **deleted**; its plaintext keys flagged for rotation). **Gotcha
  (resolved):** Hermes auto-pooled the machine's *Claude Code* credentials, and using them **logged
  the live VS Code session out** repeatedly; Anthropic's current third-party-app policy now blocks
  those subscription OAuth tokens for Hermes entirely, so Claude is off-limits to Hermes unless that
  policy changes or a non-subscription API-key path is chosen.
- **Repo integration (b):** own clone `~/Developer/homelab-hermes`, dedicated read-write **deploy
  key** (`github-hermes` alias, write access on the repo), commit identity
  `Hermes <hermes@ryankennedy.dev>`. **Proven:** Hermes added an idea to `ideas.md` and pushed to
  `origin/main` (commit `4f5c082`), independently verified; all three clones refreshed. **Three
  clones now exist** (Claude's working clone, Hermes's read-write clone, the architect's read-only
  clone on CT175) — refresh the others after any push.
- **Loop (c) — DONE:** `@hermes` joined **Drafting Table** over **direct E2EE Matrix**,
  mention-gated. The "no build path on modern macOS" blocker was **Apple-Silicon-specific** — on this
  **Intel** Mac, `brew install libolm` + the `mautrix[encryption]` extra build fine, proven
  end-to-end (E2EE bootstrap + decrypt/reply). Non-admin account, token minted via `localhost:8008`
  on CT171 (device `hermes`), env-driven config in `~/.hermes/.env`, recovery key backed up off-box;
  the initial Anthropic auth pool stayed `hermes_pkce`-only until the later `openai-codex` cutover.
  Two Hermes-specific **gating traps** fixed to match the other
  bots: `MATRIX_AUTO_THREAD=false` + `MATRIX_THREAD_REQUIRE_MENTION=true` (auto-thread was bypassing
  the mention gate), and a **tracked vendor patch** to `adapter.py` `_is_bot_mentioned` removing
  bare-name matching (pill-only, re-apply after upgrades). `MATRIX_ALLOWED_USERS` already includes
  both bots (the enabler for pill handoff — verified `@openclaw`→`@hermes`). Open/non-blocking:
  division of labor (`@openclaw` cluster-side vs `@hermes` Mac-side, plan with the architect). The
  gateway is now **durable** — a launchd LaunchAgent (`ai.hermes.gateway`, `RunAtLoad`+`KeepAlive`),
  survives reboot/crash; restart verifies E2EE via the pinned recovery key. Approval posture is
  unchanged: `approvals.mode=manual`, `cron_mode=deny`, destructive slash commands confirmed. Full record:
  `docs/hermes/hermes-mac.md`.

---

## Omega (Mac OpenClaw executor replacement) — D012 ACTIVE

**Status: Phase 3 in progress (2026-07-01).** Omega is the planned OpenClaw-based successor to Hermes: a Mac-side gateway/agent using the `claude-cli` runtime on Ryan's Claude Max subscription, with Hermes kept installed-but-disabled only at final cutover.

- **Phase 1 complete:** OpenClaw 2026.6.10 installed on the Mac under `~/.openclaw`, durable via launchd `ai.openclaw.omega.gateway`, loopback `:18790`, runtime `/Users/ryan/.local/bin/claude`, isolated `CLAUDE_CONFIG_DIR=/Users/ryan/.openclaw/.claude`, dedicated Max setup-token, and no eviction of Ryan's interactive Claude Code session.
- **Phase 2 complete:** Matrix identity `@omega:matrix.ryankennedy.dev` joined Drafting Table (`!FKZTkwAIkROBtdHyCl`), plugin running healthy, E2EE/cross-signing/key backup verified, `contextVisibility: all`, `historyLimit: 50`, `requireMention: true`, `allowBots: mentions`. Live gates: full-MXID handoff from `@openclaw` woke omega and produced an encrypted reply; unmentioned control message stayed silent.
- **Phase 2.5 complete:** Ryan-initiated DM path is functional for `@omega` (Ryan-only `dm.allowFrom`, `dm.sessionScope: per-room`, Matrix `autoJoin: allowlist` for Ryan). The test invite was manually API-accepted, so autoJoin auto-fire remains unproven; clean re-test = Ryan re-invites with no manual join and watch one sync cycle.
- **Phase 3 in progress:** Steps 1–2 are done. `gpt-5.5` codex-OAuth fallback is live (`sonnet-4-6 → gpt-5.5`) and verified by a real one-shot probe; exec is live as a mention-gated peer executor matching `main`'s posture. Finding: OpenClaw `approvals.exec` / `tools.exec` do not wrap `claude-cli`'s native Bash, and Claude Code settings denials were ignored because the backend runs with permissions bypassed; per-action approval for `claude-cli` would require native Claude Code hook/permission-prompt support and is a fleet-wide decision.
- **Phase 3 Step 3 (git write path) complete (2026-07-01):** `github-omega` deploy key registered write-enabled (Ryan); omega clone + commit identity `Omega <omega@ryankennedy.dev>`; omega proved its own commit+push live (commits `1ab1f81`, `8b0fe75`) and the post-commit auto-pull hook was verified firing to the CT175 clone (architect's clone also auto-advanced during the session).
- **Not canonical executor yet:** Phase 3 resumes at Step 4 (one infra action, verified live) then Step 5 (parity) before Phase 4 cutover. Hermes remains the active read-write executor until cutover. Cleanup: omega's `omega_homelab_ed25519` is authorized as **root on pve01** (over-privileged, from ungated provisioning) and its CT175 authorization is not yet doc-confirmed; scope to least privilege and confirm CT175 as part of Step 4.

---

## Proxmox / pfSense

Established infrastructure. Proxmox docs partly compiled (knowledge-base + setup); old notes still being consolidated. pfSense runs WireGuard (always-on phone client, LAN-IP access off-network), which already covers remote access, so Tailscale is optional/later.

---

## On the horizon (not yet active)

Hermes on Mac — **fully done (P006a/b/c, 2026-06-24/25)**: standalone + repo integration + the
Matrix loop (`@hermes` live in Drafting Table over E2EE; the `python-olm` blocker was
Apple-Silicon-specific and didn't apply to this Intel Mac). Other threads: Proxmox maintenance
agent (lives on Mac/Hermes, SSHes in, independent of the system it fixes) → local Whisper
(deployed last via the Proxmox agent). *(Ollama LXC done — P005.)* A small local chat model on the
Ollama tier (heartbeat/classification offload) and the "architect on a local model" decision can
now be taken empirically.

**Docs track (P007 + P008 complete, 2026-06-25):** `STYLE.md` is live in `docs/meta/` (house style conventions + architect response-style spec + voice section). The mechanical floor is in place: markdownlint (structure) + Vale (prose, `warning` level, non-blocking). Config files in repo root (`.vale.ini`, `.markdownlint.jsonc`); styles under `styles/Homelab/`. See `docs/meta/linting.md` for how to run. **P008 (sort pass) complete:** zero non-MD013 markdownlint errors, zero Vale Terms warnings, body-prose em-dashes rewritten across all docs, `docs/ollama/knowledge-base/` stub created. Remaining EmDash hits (29) are all H1 titles or bold-lead `**X — Y:**` status labels (STYLE.md §3 convention, intentionally exempt).
