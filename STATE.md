# Homelab — Current State

*The narrative snapshot of where everything stands right now, a complete overview of the entire homelab cluster. Read this first. For the ordered task list see `projects.md`; for the idea pool see `ideas.md`; for per-subject detail see `docs/<subject>/`.*

**Last updated:** 2026-06-23

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
- Semantic memory unavailable — embeddings need OpenAI embeddings entitlement that Codex OAuth doesn't grant. Deferred to the local Ollama tier rather than provisioning a soon-redundant paid key. Keyword/`rg` search is the interim. Note: `openclaw memory search` can exit 0 with empty output after a silent embedding failure — empty ≠ absence.
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

**Two-agent loop (P004 — live):** Both bots in one encrypted room (**Drafting Table**, `!FKZTkwAIkROBtdHyCl`) with `@ryan`. `@architect` (account `architect`, Opus) plans; `@openclaw` (account `default`, gpt-5.5) executes; `@ryan` gates. **Multi-account migration was additive** — `@openclaw` stayed the implicit top-level `default` account (token + E2EE store untouched); only `accounts.architect` was added (the plugin connects the accounts map *plus* the implicit default, so no relocation was needed). Routing bound via `openclaw agents bind` (no scope wall). **Mention-gated:** `channels.matrix.rooms[<id>]` with `allowBots:"mentions"` + `requireMention:true` (applies to both accounts), `botLoopProtection` on — nothing fires unless `@`-mentioned. **Verified:** architect plans when mentioned, openclaw stays silent when not (the brake), both reachable live (closes the deferred gateway-path proof), and the **bot→bot handoff works** — architect addressing `@openclaw` triggers it autonomously. One required tweak: `contextVisibility:"all"` (default filters out other bots' messages, so a bot couldn't read the other's plan until set). Architect's token was minted via `localhost:8008` on CT171 — **the public URL rejects password-login (403)** while token auth works, a finding that also proved the bot creds file is *not* stale. Full record: `docs/openclaw/two-agent-loop.md`.

---

## Proxmox / pfSense

Established infrastructure. Proxmox docs partly compiled (knowledge-base + setup); old notes still being consolidated. pfSense runs WireGuard (always-on phone client, LAN-IP access off-network) — this already covers remote access, so Tailscale is optional/later.

---

## On the horizon (not yet active)

Ollama LXC (hosts embeddings once proven, resolving the semantic-memory gap) → Hermes on Mac (standalone → homelab-repo integration → OC bridge) → Proxmox maintenance agent (lives on Mac/Hermes, SSHes in — independent of the system it fixes) → local Whisper (deployed last via the Proxmox agent).
