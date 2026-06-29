# Omega — Mac OpenClaw executor (Hermes replacement)

**Status:** Planned 2026-06-29. Replace Hermes with an OpenClaw agent (`omega`) on the Mac, running the `claude-cli` runtime against Ryan's Claude **Pro/Max subscription** (first-party OAuth — sidesteps the Anthropic third-party block that forced Hermes onto OpenAI). Solves OpenAI-usage burn **and** Hermes's buffer/session/reset quirks. Proven pattern: architect/main already run `claude-cli` on CT175.

**Decisions:** name `omega`; git key/identity `github-omega` (separate creds, least-privilege); **new** Matrix identity for omega (not reused from Hermes); **port CT175's tuned config** (contextPruning, params, memorySearch, behavior conventions) — adapt host-specific bits only; **keep Hermes installed-but-disabled as rollback — do NOT uninstall.**

**Research (2026-06-29):** OpenClaw is gateway-centric (one gateway/host); cross-machine agents coordinate via the shared Matrix room (as architect/main↔Hermes do now), not a native mesh. `claude-cli` = CLI-backend runtime (Anthropic model executed via local Claude CLI on the subscription). ACP runtime exists but docs say "use only when explicitly asked" — not chosen. No dedicated OpenClaw VS Code extension; overlap is shared Claude-Code runtime + shared MCP servers. Hermes's bundled "Claude Code" skill (delegate coding to Claude Code on subscription) was the lighter option #1 — **#2 full replacement chosen.**

**Plan (phased, gated; rollback = Hermes disabled-not-removed):**

- **Phase 0 — Prereqs + parity inventory (read-only):** confirm Mac has Claude Code v2.x on Pro/Max OAuth + Node/npm; inventory Hermes's capabilities (Matrix bot, git read-write push, Ansible/Proxmox SSH) = the parity checklist.
- **Phase 1 — Install OpenClaw on Mac (additive):** Mac gateway (own instance); wire `claude-cli` runtime to the Mac's `claude` binary; **port CT175's tuned config**, adapt host bits. Gate: `models status --probe` runs a turn via Claude Code on the subscription.
- **Phase 2 — Matrix wiring:** new Matrix identity for omega on CT171, E2EE + recovery key off-box; room config `requireMention:true`, `allowBots:"mentions"`, `session_scope:room`, `contextVisibility:"all"`, `historyLimit:50` (gives omega the buffer Hermes lacked). Gate: omega answers on full-MXID mention, E2EE works, architect/main can hand off.
- **Phase 3 — Executor capabilities:** repo clone + `github-omega` write key + distinct commit identity; read-write/exec with **manual approvals**, no `--yolo` on gateway; replicate Hermes's Ansible/Proxmox SSH reach. Gate: real commit+push under omega identity + one infra action, verified live.
- **Phase 4 — Parity check + cutover:** tick every Phase-0 item; only then `hermes gateway stop` (unload LaunchAgent, dormant = rollback). Gate: loop runs architect+main+omega, Hermes silent.
- **Phase 5 — Docs + cleanup:** update STATE.md + docs/hermes (mark superseded), version omega's identity in `agents/omega/`, document Hermes re-enable for rollback.
