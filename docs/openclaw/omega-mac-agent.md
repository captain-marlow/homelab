# Omega — Mac OpenClaw executor (Hermes replacement)

**Status:** Phase 2 complete 2026-06-30. Replace Hermes with an OpenClaw agent (`omega`) on the Mac, running the `claude-cli` runtime against Ryan's Claude **Pro/Max subscription** (first-party OAuth — sidesteps the Anthropic third-party block that forced Hermes onto OpenAI). Solves OpenAI-usage burn **and** Hermes's buffer/session/reset quirks. Proven pattern: architect/main already run `claude-cli` on CT175.

**Decisions:** name `omega`; git key/identity `github-omega` (separate creds, least-privilege); **new** Matrix identity for omega (not reused from Hermes); **port CT175's tuned config** (contextPruning, params, memorySearch, behavior conventions) — adapt host-specific bits only; **keep Hermes installed-but-disabled as rollback — do NOT uninstall.**

**Research (2026-06-29):** OpenClaw is gateway-centric (one gateway/host); cross-machine agents coordinate via the shared Matrix room (as architect/main↔Hermes do now), not a native mesh. `claude-cli` = CLI-backend runtime (Anthropic model executed via local Claude CLI on the subscription). ACP runtime exists but docs say "use only when explicitly asked" — not chosen. No dedicated OpenClaw VS Code extension; overlap is shared Claude-Code runtime + shared MCP servers. Hermes's bundled "Claude Code" skill (delegate coding to Claude Code on subscription) was the lighter option #1 — **#2 full replacement chosen.**

**Plan (phased, gated; rollback = Hermes disabled-not-removed):**

- **Phase 0 — Prereqs + parity inventory (read-only):** confirm Mac has Claude Code v2.x on Pro/Max OAuth + Node/npm; inventory Hermes's capabilities (Matrix bot, git read-write push, Ansible/Proxmox SSH) = the parity checklist. **Hard go/no-go — auth isolation:** confirm omega's `claude-cli` runtime can authenticate to the subscription from an **isolated credential store** (own login / separate credentials path) *without evicting Ryan's interactive Claude Code session* on the Mac. CT175 proves multi-agent `claude-cli` on one subscription, but that host has no interactive human user — the Mac does. Hermes precedent: auto-pooling the Mac's Claude Code creds repeatedly logged the live VS Code session out. Isolation achievable → proceed to Phase 1 as written; not achievable → Phase 1 must solve auth isolation before install. Note subscription concurrency/usage ceiling: omega is the **3rd** `claude-cli` consumer (architect, main, omega) plus Ryan's interactive use.
- **Phase 1 — Install OpenClaw on Mac (additive):** Mac gateway (own instance); wire `claude-cli` runtime to the Mac's `claude` binary; **port CT175's tuned config**, adapt host bits. Gate: `models status --probe` runs a turn via Claude Code on the subscription.
- **Phase 2 — Matrix wiring:** new Matrix identity for omega on CT171, E2EE + recovery key off-box; room config `requireMention:true`, `allowBots:"mentions"`, `session_scope:room`, `contextVisibility:"all"`, `historyLimit:50` (gives omega the buffer Hermes lacked). Gate: omega answers on full-MXID mention, E2EE works, architect/main can hand off.
- **Phase 3 — Executor capabilities:** repo clone + `github-omega` write key + distinct commit identity; read-write/exec with **manual approvals**, no `--yolo` on gateway; replicate Hermes's Ansible/Proxmox SSH reach. Gate: real commit+push under omega identity + one infra action, verified live.
- **Phase 4 — Parity check + cutover:** tick every Phase-0 item; only then `hermes gateway stop` (unload LaunchAgent, dormant = rollback). Gate: loop runs architect+main+omega, Hermes silent.
- **Phase 5 — Docs + cleanup:** update STATE.md + docs/hermes (mark superseded), version omega's identity in `agents/omega/`, document Hermes re-enable for rollback.

## Phase 0 findings (2026-06-29) — inventory complete, gate = conditional GO

**Environment:** Claude Code 2.1.81 (`/Users/ryan/.local/bin/claude`); on-disk auth = Claude Max OAuth (`stripe_subscription` / `claude_max` / `default_claude_max_5x`) at `~/.claude/.credentials.json` (`0600`) + `~/.claude.json`. Node v25.8.1, npm 11.11.0.

**Auth-isolation go/no-go → conditional GO.** Isolation knob confirmed: `CLAUDE_CONFIG_DIR` — omega runs with its own config dir + own Max login, isolated store, cannot evict Ryan's interactive `~/.claude` session.

- *Caveat 1 (env hygiene — de-risked):* the `ANTHROPIC_API_KEY` / `CLAUDE_CODE_OAUTH_TOKEN` vars seen during inventory are NOT injected into the Hermes launchd gateway — absent from the `ai.hermes.gateway` plist, `launchctl` bootstrap env, and the gateway process env (pid 19192). `ANTHROPIC_API_KEY` has no active source in dotfiles/`.config`/`.hermes/.env` (transient in an earlier interactive shell only); `CLAUDE_CODE_OAUTH_TOKEN` exists only as a disabled/commented line in `~/.hermes/.env:16` (`#DISABLED-collides-with-ClaudeCode`), suppressed in `~/.hermes/auth.json` (old backup `.env.bak-p006c-20260624`). No durable env injection to fight; mitigation = omega's gateway launches with an explicit clean env + its own `CLAUDE_CONFIG_DIR`. The "Not logged in" from `claude auth status` during inventory was that transient shadowing, consistent with this.
- *Caveat 2 (prove live):* Phase 1's first gate — omega logs in under its own `CLAUDE_CONFIG_DIR`, runs a turn, and Ryan's interactive Claude Code session survives — before any config port.

**Parity checklist (omega must match):**

- *Matrix:* Hermes gateway `ai.hermes.gateway` (launchd); room gating already allows `@openclaw` + `@architect`; omega = new identity, same shape.
- *Git r/w:* Hermes clone `~/Developer/homelab-hermes`, remote `git@github-hermes:captain-marlow/homelab.git`, key `~/.ssh/hermes_homelab_deploy`, repo-local identity `hermes@homelab`; omega = own `github-omega` key + clone + distinct identity.
- *Infra:* SSH aliases `openclaw` (.175) + `pve01` (.19 root) both live; Proxmox `pvesh`/`qm`/`pct` on pve01; ansible inventory `config/proxmox/ansible/inventory/hosts.ini`. Both aliases share `~/.ssh/id_ed25519` → omega should get its own key (least-privilege).

## Decisions locked (2026-06-29)

- Agent `omega`; gateway home `~/.openclaw` (clean — the stale March `~/.openclaw` was deleted in P006); isolated auth `CLAUDE_CONFIG_DIR=~/.openclaw/.claude` (separate from Ryan's interactive `~/.claude`).
- Auth method: **dedicated Max setup-token** (same mechanism as architect/main on CT175), not interactive `claude auth login` — sidesteps device-login eviction by construction.
- Own SSH keypair, proper-named `omega_homelab_ed25519` (parallels Hermes's `hermes_homelab_deploy`); provisioned onto **pve01** (`root@192.168.1.19`) and CT175 (`openclaw@192.168.1.175`).
- Git: `github-omega` write deploy key, own clone, commit identity `Omega <omega@ryankennedy.dev>`.
- Model chain: mirror main (executor tier) — `anthropic/claude-sonnet-4-6` → `openai/gpt-5.5`.
- Isolation posture: same macOS user (`ryan`), config-level boundary (`CLAUDE_CONFIG_DIR` + clean env). Separate-macOS-user is the hardening fallback if the live non-eviction test fails.

## Phase 1 — install + wire `claude-cli` (detailed, additive; Hermes stays live)

**Step 1 — Auth-isolation proof (opening gate, caveat 2). Before installing anything:**

1. Create `~/.openclaw/.claude`.
2. Mint omega a dedicated Max setup-token into that dir (Ryan present for the mint).
3. In a clean shell (`CLAUDE_CONFIG_DIR=~/.openclaw/.claude`, no inherited `ANTHROPIC_API_KEY`/`CLAUDE_CODE_OAUTH_TOKEN`), run one trivial `claude` turn → succeeds on the subscription.
4. Non-eviction check: confirm Ryan's interactive Claude Code (`~/.claude`) is still logged in — no re-login prompt.

*Gate:* omega runs a turn from its own dir AND Ryan's interactive session survives. If Ryan's session is evicted → STOP, isolation failed, fall back to separate-macOS-user.

**Step 2 — Install the gateway:**

- Install OpenClaw (match CT175's line), gateway home `~/.openclaw`, single agent `omega`, runtime `claude-cli` → `/Users/ryan/.local/bin/claude`, model chain sonnet-4-6 → gpt-5.5.
- Run under a launchd LaunchAgent (mirroring `ai.hermes.gateway`) with an explicit clean env + `CLAUDE_CONFIG_DIR=~/.openclaw/.claude`.
- Port CT175's tuned config (contextPruning TTL 20m, params, behavior conventions). `memorySearch` → Ollama on CT172 is LAN-reachable but **deferred** in Phase 1 (one variable at a time).

**Step 3 — Probe gate:** `openclaw models status --probe` runs a real turn through `claude-cli` on the subscription. *Gate:* successful turn.

**Rollback:** omega has no Matrix surface and no write/exec/SSH yet — isolated local install. Tear-down = remove `~/.openclaw` + revoke omega's setup-token; Hermes untouched.

## Phase 1 — COMPLETE (2026-06-30)

Omega is installed, configured, durable, and isolated on the Mac. Probes `usable`; Ryan's interactive Claude Code confirmed unaffected.

**Install & runtime**

- OpenClaw 2026.6.10 on the Mac (npm global; `/usr/local` prefix is `ryan:admin`, no sudo). Gateway home `~/.openclaw`, loopback `:18790`.
- Single agent `omega`, runtime `claude-cli` → `/Users/ryan/.local/bin/claude` (2.1.195). Node v25.8.1 (compat confirmed).

**Auth & isolation**

- omega authenticates on a dedicated **Anthropic Max setup-token** (subscription OAuth, not an API key), stored in omega's **own sqlite** (`~/.openclaw/agents/omega/agent/openclaw-agent.sqlite`). `CLAUDE_CONFIG_DIR=/Users/ryan/.openclaw/.claude`, shell env off.
- Fully isolated from Ryan's interactive Claude Code, which uses the **macOS Keychain** (Claude Code 2.1.195 stores first-party OAuth in Keychain, not `~/.claude/.credentials.json`).
- **Eviction scare resolved as a false-positive:** the SSH check reporting `.credentials.json` absent + "Not logged in" was (a) creds now in Keychain, (b) non-interactive SSH can't read Keychain. Ryan's interactive `claude auth status` = `loggedIn: true`, `max`, `firstParty`. No eviction occurred.

**Model chain**

- omega: primary `anthropic/claude-sonnet-4-6`; fallback `openai/gpt-5.5` **pending** (codex/subscription OAuth — no API key per policy). `opus-4-8` left wired (+`opus` alias) for a future agent.
- Fleet, verified live (docs were accurate — no drift): `main` `sonnet-4-6→gpt-5.5`; `architect` `opus-4-8→gpt-5.5`; `omega` `sonnet-4-6→gpt-5.5`. The `claude-cli/claude-opus-4-6` in probe output is the anthropic **plugin catalog** target, not routing.

**Durability**

- launchd LaunchAgent `ai.openclaw.omega.gateway` (`RunAtLoad`+`KeepAlive`). Env: `PATH=/usr/local/bin:/Users/ryan/.local/bin:/usr/bin:/bin`, `CLAUDE_CONFIG_DIR=/Users/ryan/.openclaw/.claude`, `OPENCLAW_MDNS_HOSTNAME=omega-openclaw`. Auto-recovery verified (`launchctl kickstart -k`).
- mDNS advertises `omega-openclaw.local` (Mac OS hostname is `omega` → clash resolved). `OPENCLAW_MDNS_HOSTNAME` is **env-only** (no config key).

**Auth principle (durable fleet policy):** **No API keys, ever — subscription-based OAuth only.** Anthropic Max setup-tokens (each agent its own, shared Max sub) and OpenAI codex/ChatGPT-subscription OAuth (each agent its own session). Independently revocable per agent.

**Operational gotchas:**

- `meta.lastTouchedAt`: raw file overwrites (`cat >`) trip the gateway's auto-restore-from-last-good — use `openclaw config set`.
- CT175 `anthropic:claude-cli` OAuth expiry is non-breaking (static durable token leads); refresh via `openclaw models auth login --provider anthropic --method cli` when convenient.

## Phase 2 — COMPLETE (2026-06-30)

Omega is wired into the Drafting Table Matrix room as a new, E2EE-capable, mention-gated agent. Hermes remains live; omega is additive and not yet the read-write executor.

**Matrix account & room**

- Account `@omega:matrix.ryankennedy.dev`, device `omega`; token stored off-repo in `~/.homelab-secrets/matrix-omega-access-token.txt` (`0600`).
- `whoami` verified `user_id=@omega:matrix.ryankennedy.dev`, `device_id=omega`.
- Joined room `!FKZTkwAIkROBtdHyCl:matrix.ryankennedy.dev`; current joined members include `@ryan`, `@openclaw`, `@architect`, `@hermes`, and `@omega`.

**OpenClaw channel config**

- Matrix plugin installed and running; `openclaw config validate` passes.
- `channels.matrix` is enabled with `defaultAccount: omega`, `homeserver: https://matrix.ryankennedy.dev`, `encryption: true`, `contextVisibility: all`, `historyLimit: 50`, `autoJoin: off`, and `allowBots: mentions`.
- Drafting Table room config: `account: omega`, `requireMention: true`, `allowBots: mentions`, `botLoopProtection.enabled: true`.
- Channel health verified via `openclaw channels status --json`: Matrix running, account `omega` connected, health `healthy`.

**E2EE & verification**

- E2EE bootstrap output stored off-repo in `~/.homelab-secrets/matrix-omega-e2ee-bootstrap.json` (`0600`).
- `openclaw matrix verify status --account omega --json` reports `verified: true`, `localVerified: true`, `crossSigningVerified: true`, `signedByOwner: true`, server device known, key backup trusted, backup version `1`.

**Live gates**

- **Mention / bot handoff:** `@openclaw` sent a full-MXID pill for `@omega:matrix.ryankennedy.dev`; omega reacted, then replied as encrypted event `$frA4D30M5MJMpMJKVX37s3FrUt7gRLKga4gQCpDNA5g`.
- **Brake:** `@openclaw` sent an unmentioned control message; 20-second watch showed no omega reaction or reply.

**Known caveat**

- Reading older Hermes-encrypted messages through omega currently shows Megolm "sender's device has not sent us the keys" for some Hermes events. This does **not** block omega's own Matrix send/receive path, but it means historical Hermes ciphertext is not a Phase-2 proof source. Future validation should use fresh encrypted client messages or bot handoffs after all devices have shared room keys.

## Phase 2.5 — Ryan→omega DM enabled (2026-06-30)

Omega now accepts direct messages from Ryan as a human-to-agent path. This is deliberately **not** a bot↔bot DM path; bot handoff stays in Drafting Table via full-MXID mentions.

**Config change**

- DM access remains Ryan-only: `dm.allowFrom: ["@ryan:matrix.ryankennedy.dev"]`, with `dm.sessionScope: per-room` so encrypted DM context stays isolated from room sessions.
- The Matrix channel was patched with `openclaw config set` (not raw file edits, to preserve `meta.lastTouchedAt`) to change `autoJoin: off → allowlist` and set `autoJoinAllowlist: ["@ryan:matrix.ryankennedy.dev"]`. Persistence was verified after gateway restart.
- omega's stale `m.direct` state was cleared during the fix so the active Ryan↔omega DM room is the canonical direct channel.

**Live gate**

- Ryan-initiated DM is functional: omega decrypts and replies in the DM without needing an `@omega` mention. This is intentionally narrower than room behavior, where `requireMention: true` remains the brake.

**Caveat — autoJoin auto-fire unverified**

- The invite used during the test was manually API-accepted, so the test cannot distinguish "autoJoin fired late" from "autoJoin did not fire." Do **not** record this as an auto-join delay bug.
- Clean re-test, if it matters later: Ryan re-invites omega with no manual intervention, then watch whether omega self-joins within a Matrix sync cycle.

## Phase 3 — Executor capabilities IN PROGRESS (2026-06-30/07-01)

Phase 3 is the executor-capability track. Omega is now a mention-gated peer executor matching `main`'s exec posture, but it is not yet the canonical repo/infra writer. Hermes remains the active read-write/git-push executor until Phase 4 cutover.

**Step 1 — `gpt-5.5` codex-OAuth fallback: DONE**

- Device-code login completed for profile `openai:ryan+openai@ryankennedy.me` (`openai/oauth`).
- Omega's model chain is now `anthropic/claude-sonnet-4-6 → openai/gpt-5.5`, persisted through gateway restart.
- Verified live with a direct one-shot probe: `gpt-5.5` returned real output, not just "configured."

**Step 2 — exec: DONE**

- Omega runs as a **mention-gated peer executor matching `main`'s posture**: `tools.exec` at defaults (`security=full`, `ask=off`), `approvals.exec.enabled=false`, and an empty `CLAUDE_CONFIG_DIR` `settings.json`.
- Verified live on request by running `date`.

**Exec-model finding — do not re-run**

- OpenClaw's `approvals.exec` / `tools.exec` governs **OpenClaw-owned tools only**; it does **not** wrap `claude-cli`'s native Bash path. That Bash is runtime-owned by Claude Code. The relevant OpenClaw doc is `concepts/agent-runtimes.md`: "Shell, patch, and runtime-owned tools need native hook support for policy and observation."
- The `claude-cli` backend runs Claude Code with permissions bypassed, so `CLAUDE_CONFIG_DIR` `settings.json` `permissions.deny: ["Bash(*)"]` was also ignored at runtime.
- Net: **`claude-cli` executors are gated by mention + operator, not per-action approval** — the same posture as `main`. A per-action approval wall for a `claude-cli` agent chases a layer that is not in the exec path. Real per-action gating, if ever wanted, needs a native mechanism (Claude Code `PreToolUse` hook / permission-prompt-tool) and is a fleet-wide decision, not omega-specific.

**Step 3 — `github-omega` write path: DONE (2026-07-01)**
- Deploy key registered write-enabled on the repo (Ryan); omega has its own clone + identity `Omega <omega@ryankennedy.dev>`.
- Omega proved its own commit+push live — commits `1ab1f81` (git gate) and `8b0fe75` (auto-pull verify), both authored+committed by omega.
- Post-commit auto-pull hook verified firing to CT175 (per `8b0fe75`); architect's clone also auto-advanced during the session.

**Remaining Phase 3**
- Step 4: one infra action, verified live. `omega_homelab_ed25519` exists and is authorized on pve01 (as root — see cleanup); CT175 authorization not yet doc-confirmed. Prove reach with a real action and confirm both hosts.
- Step 5: parity review, then Phase 4 cutover decision.

**Open cleanup**

- omega's `omega_homelab_ed25519` is authorized as **root on pve01** (adopted from ungated provisioning). Scope it to least privilege when convenient.
