# Omega — Mac OpenClaw executor (Hermes replacement)

**Status:** Planned 2026-06-29. Replace Hermes with an OpenClaw agent (`omega`) on the Mac, running the `claude-cli` runtime against Ryan's Claude **Pro/Max subscription** (first-party OAuth — sidesteps the Anthropic third-party block that forced Hermes onto OpenAI). Solves OpenAI-usage burn **and** Hermes's buffer/session/reset quirks. Proven pattern: architect/main already run `claude-cli` on CT175.

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
