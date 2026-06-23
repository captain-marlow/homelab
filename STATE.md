# Homelab — Current State

*The narrative snapshot of where everything stands right now, a complete overview of the entire homelab cluster. Read this first. For the ordered task list see `projects.md`; for the idea pool see `ideas.md`; for per-subject detail see `docs/<subject>/`.*

**Last updated:** 2026-06-22

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

## Next major track: Matrix two-agent loop (architect + main)

**Status: active — P001 (Synapse homeserver) DONE (2026-06-22); P002 (Matrix plugin + single-bot proof) is the current step. Runs before Ollama.**

Replicate the current planning loop (Opus planner → human gate → executor) inside the homelab, in a self-hosted Matrix room. Planner = new `architect` agent (read-only, Opus); executor = existing OpenClaw gateway, wired in as the `@openclaw` account. Chosen because Matrix natively supports two agents in one room with `allowBots: "mentions"` as the human-gated brake, and it self-hosts. Built before Ollama because the architect loop will be used to plan every later step.

Dependency order: Synapse homeserver → Matrix plugin + single-bot proof → architect agent + doc repo → two-agent loop. See `docs/openclaw/` (architect track) for full reasoning.

**Synapse homeserver (P001 — live):** `matrix.ryankennedy.dev` on CT171 (`.171`), Postgres 16 backed, Element HQ image. Reverse-proxied by NPM on CT110 (`.110`) with a Let's Encrypt DNS-01 cert; public (80/443 NAT-forwarded), **federation off**, registration closed. Split-horizon DNS (pfSense host override → `.110` on-net; DigitalOcean → WAN off-net). Verified send/receive on desktop + phone, on-net and over WireGuard. Accounts: `@ryan` (admin), `@openclaw` + `@architect` (non-admin, reserved for the agent loop). Secrets (signing key, bot creds) off-box in `~/homelab-secrets/`. Full operational record: `docs/proxmox/synapse-matrix.md`.

---

## Proxmox / pfSense

Established infrastructure. Proxmox docs partly compiled (knowledge-base + setup); old notes still being consolidated. pfSense runs WireGuard (always-on phone client, LAN-IP access off-network) — this already covers remote access, so Tailscale is optional/later.

---

## On the horizon (not yet active)

Ollama LXC (hosts embeddings once proven, resolving the semantic-memory gap) → Hermes on Mac (standalone → homelab-repo integration → OC bridge) → Proxmox maintenance agent (lives on Mac/Hermes, SSHes in — independent of the system it fixes) → local Whisper (deployed last via the Proxmox agent).
