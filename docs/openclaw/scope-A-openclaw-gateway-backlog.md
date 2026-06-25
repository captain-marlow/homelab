# Scope A — OpenClaw Gateway: Hardening & Maintenance Backlog

**Project lineage:** continuation of the 2026-06-21 failover & auth-hardening work on the `openclaw` LXC.
**Host:** `openclaw` LXC (Proxmox CT, Debian, static `192.168.1.175`), OpenClaw 2026.6.8.
**Purpose:** finish the remaining items from the original session: the operational durability, security, and cost work on the *existing single gateway*. This scope is about making the brain you already have solid. (The Mac/Obsidian/Proxmox homelab-agent vision is a separate project; see Scope B.)

---

## Done this session (for context — not to redo)

- **Item 6 — Anthropic auth durability verified.** Durable setup-token (`anthropic:default`) confirmed leading and working through the gateway (live `alive` test, `transport: gateway`). OAuth (`claude-cli`) correctly excluded by auth-order. Decided: setup-token is the load-bearing leg; OAuth keepalive deferred to a cron/heartbeat (see backlog).
- **Item 3 — Context pruning + heartbeat applied.** `contextPruning` (`cache-ttl`, `ttl: 1h`, `keepLastAssistants: 3`, soft-trim + hard-clear) merged into `agents.defaults`; `heartbeat` set to `1h` to match `cacheRetention: "long"`. Restart applied, gateway `active (running)`, config valid. Note: pruning only acts on the Anthropic leg (OpenAI primary untouched) — it's failover-resilience insurance, not an everyday token cut.
- **PATH fix for `claude`.** `claude` binary (`/home/openclaw/.npm-global/bin/claude`, `@anthropic-ai/claude-code@2.1.183`) was installed but invisible to the systemd service. Fixed via `Environment=PATH=...` in the gateway unit. `claude-cli` probe rows now return `ok` instead of "binary not found" — the fallback leg is now actually executable.

---

## Remaining backlog (this scope)

### 1. Local Whisper (was item 4)

Replace the paid `OPENAI_WHISPER_API_KEY` (`sk-sv…`) transcription dependency with a local model (whisper.cpp or faster-whisper).

- **Note:** likely wants its own LXC. The *building* of that LXC is where this scope brushes against Scope B — but the Whisper setup itself (pick model, wire transcription path, test on a real voice note, remove the key) belongs here.
- Decision pending: build the Whisper LXC manually (lower risk) vs. via an agent (Scope B territory).

### 2. Local Ollama tier (was deferred #1)

A 4th, *unkillable* fallback under Gemini (can't expire, revoke, rate-limit, or 503). The structural answer to the triple-failure event. 64GB host can run a strong quantized model. This is the highest-value durability item.

### 3. Full SecretRef migration (was deferred #2)

Migrate remaining plaintext secrets (Telegram token, gateway token, Whisper key, web-search key) to file-backed SecretRefs → goal `openclaw secrets audit --check clean`. The Gemini key (already done) is the template. **Careful:** some are load-bearing for the control channel, so migrate one at a time, verify, keep timestamped backups.

### 4. OAuth keepalive for `claude-cli` (was item 6 watch / deferred)

Now that PATH is fixed and the leg is executable, decide whether to keep the OAuth fallback warm. Options: cron job or heartbeat hook that pings `claude` on a sub-8h cadence. **Open precondition is now cleared** (binary on PATH). Strategic question still stands: is reviving a decay-prone spare worth it when the durable token leads? Possibly skip entirely and just prune the dead `claude-cli/*` model rows from config.

### 5. MEMORY.md routing policy (was deferred #5)

Record routing/auth policy as durable bot instructions now that the chain is settled.

---

## Smaller open items (surfaced, worth folding in)

- **Embedding/semantic-memory quota exhausted** — semantic memory search was down due to embedding quota (likely Gemini/Google free-tier embeddings). Investigate which key/project backs embeddings and whether it needs isolation.
- **Two memory artifacts** — `MEMORY.md` (snapshot) vs `memory/2026-06-21.md` (dated log). Reconcile to whichever OpenClaw reads at boot.
- **`plugins.allow` is empty** — startup warns the codex plugin auto-loads. Set an explicit trusted allowlist (CVE-era hygiene).
- **Cosmetic:** Anthropic usage window no longer shows in `models status` (OpenAI's still does). Cause unresolved — was present the night before, absent now, no config change explains it. Agreed to leave it; the leg is proven healthy regardless. The Anthropic-cap watch concern is largely moot post-June-15 (CLI usage draws on a separate Agent SDK credit, not the plan limit).
- **Prune dead `claude-cli/*` model rows** if not reviving that leg (see #4).

---

## Operating discipline (carry forward)

- `systemctl --user` works cleanly via **direct SSH login** as `openclaw` (not `su` — avoids XDG_RUNTIME_DIR errors).
- **SSH shell is the source of truth, not the Telegram indicator.** A restart kills the in-flight turn; verify with `openclaw models status` / `openclaw logs --follow`.
- **Verification pattern:** `openclaw infer model run --gateway --model <provider/model> --prompt 'ping' --json` — `--gateway` forces the real path; `"transport": "gateway"` confirms. Auth-present ≠ works; works-embedded ≠ works-through-gateway.
- **Timestamped backups** are the durable rollback points (the bare `.bak` gets overwritten). Back up before every config change; run `openclaw doctor --fix` after.

---

## Suggested order

Ollama tier (#2, highest durability value) → SecretRef migration (#3, security) → Whisper (#1, may overlap Scope B for the LXC build) → keepalive decision (#4) → MEMORY policy (#5). Smaller items folded in opportunistically.
