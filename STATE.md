# Homelab — Current State

*The narrative snapshot of where everything stands right now, a complete overview of the entire homelab cluster. Read this first. For the ordered task list see `projects.md`; for the idea pool see `ideas.md`; for per-subject detail see `docs/<subject>/`.*

**Last updated:** 2026-06-24

---

## Repo

Migrated to the **category-first** layout (`config/` · `docs/` · `agents/`, subject as the namespace inside each) — **P000 complete (2026-06-22)**; see `README.md`. The pre-consolidation doc trees (`docs_old/_new/_gpt/_complete`) are kept on disk but untracked, pending D006.

---

## OpenClaw

**Status: daily driver, hardened, documented. Step 1 of the build plan complete.**

- Gateway running on the `openclaw` LXC (Proxmox CT, Debian, static `192.168.1.175`), OpenClaw 2026.6.8.
- Three-deep cross-provider text failover proven live: `openai/gpt-5.5` (Codex OAuth) → `anthropic/claude-sonnet-4-6` (durable setup-token) → `google/gemini-3-flash-preview` (file-backed key). Auto-switches on rate limit, announces once per state change.
- Anthropic durable token leads its leg; `claude-cli` OAuth demoted to manual-pin fallback.
- `MEMORY.md` is the canonical boot file (durable policy); `OPEN-ISSUES.md` holds transient state.
- Filesystem hardened (`~/.openclaw` → 700); SecretRef migration done (1 accepted plaintext exception: the static Anthropic token, which OpenClaw's SecretRef subsystem structurally can't hold).
- Recovery-notification skill active (closes the promised-but-unmechanized switch-back notice).
- Context pruning TTL tuned 1h→20m; watching peak context and cache-read over the next few large sessions.

**Deferred / watching:**
- Semantic memory **RESTORED (2026-06-24, P005)** — now served by local Ollama embeddings (`nomic-embed-text` on CT172), replacing the dead OpenAI path. `main`'s index = 7 files / 53 chunks; `openclaw memory search` returns real ranked results. Embed latency ~0.3s after the CT172 core bump (4→16). See the Ollama tier section below + `docs/ollama/ollama-tier.md`. (The silent-failure caveat still holds in general: `openclaw memory search` can exit 0 with empty output after an embedding failure — empty ≠ absence.)
- Gateway-token rotation deferred (loopback-only, low exposure) but is the matched closing step to the same-value relocation.
- Anthropic usage stats absent from dashboard post-June-15 — leading theory is a billing change; treated as cosmetic.

---

## Matrix two-agent loop (architect + main) — COMPLETE

**Status: DONE (2026-06-23) — P001 (Synapse) + P002 (Matrix bot channel) + P003 (architect agent) + P004 (two-agent loop, mention-gated) all complete. The planning loop now runs inside the homelab. Next track: Ollama (P005).**

The current planning loop (Opus planner → human gate → executor) now runs inside the homelab, in a self-hosted Matrix room (**Drafting Table**). Planner = `architect` agent (read-only, Opus); executor = the OpenClaw gateway as `@openclaw`; gate = `@ryan`. Built before Ollama because the loop is used to plan every later step (and already is — it produced a sequenced P005-vs-P006 recommendation in its first live session).

Dependency chain (all done): Synapse homeserver → Matrix plugin + single-bot proof → architect agent + doc repo → two-agent loop.

**Synapse homeserver (P001 — live):** `matrix.ryankennedy.dev` on CT171 (`.171`), Postgres 16 backed, Element HQ image. Reverse-proxied by NPM on CT110 (`.110`) with a Let's Encrypt DNS-01 cert; public (80/443 NAT-forwarded), **federation off**, registration closed. Split-horizon DNS (pfSense host override → `.110` on-net; DigitalOcean → WAN off-net). Verified send/receive on desktop + phone, on-net and over WireGuard. Accounts: `@ryan` (admin), `@openclaw` + `@architect` (non-admin). Secrets (signing key, bot creds) off-box in `~/homelab-secrets/`. Full record: `docs/proxmox/synapse-matrix.md`.

**Matrix bot channel (P002 — live):** OpenClaw gateway (CT175) wired to Synapse as `@openclaw` via the `@openclaw/matrix@2026.6.8` channel plugin (config-edited directly into `openclaw.json`, since the box CLI is intentionally read-only). Bot reads/responds over Matrix, gated to `@ryan` (`dm.allowFrom`). **E2EE working** — encryption auto-bootstrapped `@openclaw`'s cross-signing + self-verified device; bot decrypts and replies encrypted. `dm.sessionScope=per-room` isolates rooms (so encrypted content can't bleed into unencrypted replies). Encrypted-invite auto-join is finicky → bot is joined into rooms manually (one-time per room; small fixed set). Follow-ups: user-verify `@openclaw` (green shield), back up E2EE recovery key off-box, resolve the pending CLI scope request. Full record: `docs/openclaw/matrix-bot-channel.md`.

**Architect agent (P003 — live):** Second OpenClaw agent (`architect`) on CT175 alongside `main` — the read-only planner half of the loop. Pinned to `anthropic/claude-opus-4-8` on its **own dedicated Max setup-token** (separate auth store from `main`, independently revocable). **Read-only / deny-exec** by tool policy (effective tools `read`/`message`/`session_status`, exec denied, `sandbox.workspaceAccess=ro`, `skills:[]`) — proven live in its system-prompt report. Reads the homelab repo as its knowledge base: cloned into its workspace via a **read-only GitHub deploy key** (under the `openclaw` user, `github-homelab` SSH alias), refreshed by manual `git pull`. Identity (`IDENTITY/USER/SOUL.md`) authored in the repo at `agents/architect/` and **symlinked** into the workspace root; `BOOTSTRAP.md` removed; no `MEMORY.md` (the repo is its memory). Verified answering on Opus, grounded in the docs. Bound on Matrix in P004. Full record: `docs/openclaw/architect-agent.md`.

**Two-agent loop (P004 — live):** Both bots in one encrypted room (**Drafting Table**, `!FKZTkwAIkROBtdHyCl`) with `@ryan`. `@architect` (account `architect`, Opus) plans; `@openclaw` (account `default`, gpt-5.5) executes; `@ryan` gates. **Multi-account migration was additive** — `@openclaw` stayed the implicit top-level `default` account (token + E2EE store untouched); only `accounts.architect` was added (the plugin connects the accounts map *plus* the implicit default, so no relocation was needed). Routing bound via `openclaw agents bind` (no scope wall). **Mention-gated:** `channels.matrix.rooms[<id>]` with `allowBots:"mentions"` + `requireMention:true` (applies to both accounts), `botLoopProtection` on — nothing fires unless `@`-mentioned. **Verified:** architect plans when mentioned, openclaw stays silent when not (the brake), both reachable live (closes the deferred gateway-path proof). **Bots CAN trigger each other — via the full MXID** (`@openclaw:matrix.ryankennedy.dev`), which OpenClaw converts to a real `m.mentions` pill (`was_mentioned:true`); a bare localpart (`@openclaw`) is inert text. So autonomous planner↔executor handoff works — `@ryan` isn't strictly required to relay, and a two-way loop is possible. Brakes are by convention + backstop, not a hard wall: kill-switch = omit the mention, `botLoopProtection` (20/60s), `requireMention:true`, and agent SOUL discipline. `contextVisibility:"all"` lets a triggered bot read the other's message. (Earlier "bots can't auto-trigger" was a full-MXID-vs-localpart misdiagnosis, corrected after live testing.) Fresh session = `/reset` or `/new` in the room. Architect's token was minted via `localhost:8008` on CT171 — **the public URL rejects password-login (403)** while token auth works, a finding that also proved the bot creds file is *not* stale. Full record: `docs/openclaw/two-agent-loop.md`.

---

## Ollama local-AI tier (CT172) — COMPLETE

**Status: DONE (2026-06-24) — P005. Local embeddings now back OpenClaw semantic memory; the OpenAI entitlement gap is closed without a paid key.**

A CPU-only Ollama runner on its own LXC (`192.168.1.172`, same `proxmox_lxc_docker_host` Ansible role as the other stacks; Docker + Komodo Periphery). Hosts one embedding model, **`nomic-embed-text`** (768-dim), **LAN-only** (port bound to the LXC IP, no pfSense NAT forward; Ollama is auth-less, so the LAN is the boundary). Model blobs persist on the ZFS `flash` pool.

OpenClaw's `agents.defaults.memorySearch` was repointed `provider: openai → ollama` (first-class provider; hits `/api/embed`; `batch:false`, `fallback:none`), gateway restarted, index force-rebuilt → **7 files / 53 chunks**; `memory search` returns real ranked hits (positive test, empty≠absence). **Perf finding:** first build was ~7s/embed because CT172 had only 4 of the host's 32 threads on a **hybrid P/E-core CPU** (threads likely on E-cores); `pct set 172 -cores 16` dropped embed latency to **~0.3s** (~20–40× faster). GPU deferred; a small local chat model for cheap-task offload is the next use of this tier (separate step). Full record: `docs/ollama/ollama-tier.md`.

---

## Proxmox / pfSense

Established infrastructure. Proxmox docs partly compiled (knowledge-base + setup); old notes still being consolidated. pfSense runs WireGuard (always-on phone client, LAN-IP access off-network) — this already covers remote access, so Tailscale is optional/later.

---

## On the horizon (not yet active)

Hermes on Mac (standalone → homelab-repo integration → OC bridge) → Proxmox maintenance agent (lives on Mac/Hermes, SSHes in — independent of the system it fixes) → local Whisper (deployed last via the Proxmox agent). *(Ollama LXC done — P005.)* A small local chat model on the Ollama tier (heartbeat/classification offload) and the "architect on a local model" decision can now be taken empirically.
