# Hermes — Proper Setup & Hardening

**Status:** planning  
**Project ID:** P010 (see `projects.md`)  
**Last updated:** 2026-06-26

---

## Motivation / Incident (2026-06-26)

Hermes was brought online as the read-write / git-push executor (P006) without the deliberate
setup OpenClaw received: no hardening, no scoped permissions, no documented lifecycle. The
2026-06-26 stalled-stream incident exposed this:

- Provider stream stalled silently; `stale stream detected after 1096s, reconnecting` — stuck on
  iteration 1/60 for ~18 minutes before reconnecting.
- During cleanup, Hermes emitted repeated "⚠️ Gateway shutting down" interrupts and stayed online
  past a `launchctl stop` attempt (which auto-respawns due to `KeepAlive: true` in the plist).
- Correct stop command (`hermes gateway stop`) was not documented; launchctl confusion delayed
  recovery.
- No fallback providers configured — when the stream stalled, there was nothing to catch it.

Root cause: Hermes was never properly set up. Goal: bring Hermes to setup parity with OpenClaw
and eliminate autonomous action.

---

## Runtime Facts (verified 2026-06-26 via SSH)

- **LaunchAgent:** `ai.hermes.gateway` (`~/Library/LaunchAgents/ai.hermes.gateway.plist`)
- **KeepAlive:** `true` — `launchctl stop` will auto-respawn. Use `hermes gateway stop`.
- **Home:** `~/.hermes/`
- **Runtime:** Python venv at `~/.hermes/hermes-agent/venv/`
- **Config:** `~/.hermes/config.yaml`
- **Logs:** `~/.hermes/logs/gateway.log` / `gateway.error.log`
- **Resolved model:** `anthropic/claude-sonnet-4-6` via OpenRouter (`https://openrouter.ai/api/v1`)
- **Fallbacks:** none (`fallback_providers: []`)
- **No `--yolo` flag** in plist ProgramArguments — exec gating is nominally on

---

## Sequenced Plan

### 1. Security — Eliminate Autonomous Action (headline)

This is the priority. Hermes is the write-capable / git-push executor; an executor that acts
unprompted is the dangerous combination.

- [ ] Audit what Hermes can currently do unprompted
- [ ] Confirm `HEARTBEAT.md` is empty / comments-only — no self-triggered API calls
- [ ] Audit cron — no self-scheduled write/push tasks
- [ ] Enforce: **pill-only wake, gate every write/push.** No `git push`, repo edit, or Ansible
      run without an explicit gated request
- [ ] Define revert condition: if any unprompted write is observed post-hardening, hard-stop Hermes

### 2. Least-Privilege Scoping (mirror OpenClaw)

- [ ] Separate, dedicated credentials — no shared keys; secrets off-repo
- [ ] Scoped tool access: only what the executor role needs (repo edits, Ansible, Mac/Proxmox ops)
- [ ] Add fallback provider(s) so a stalled stream degrades gracefully rather than going dark
- [ ] Verify resolved model and provider/quota binding after any credential changes

### 3. Clean Lifecycle + Stability

- [ ] Document correct stop/start: `hermes gateway stop` / `hermes gateway start` — **not** launchctl
      for app-level lifecycle
- [ ] Reduce stale-stream timeout — ~1096s before reconnect is too patient; target a few minutes
      so stalls self-heal instead of looking like an 18-minute hang
- [ ] Document the "gateway shutting down" interrupt behaviour and how to cleanly halt mid-turn
- [ ] Add at least one fallback provider so model unavailability doesn't silence Hermes entirely

### 4. Setup Parity Scaffolding

Match the deliberate setup OpenClaw received:

- [ ] `AGENTS.md` — role definition, red lines, conventions
- [ ] `SOUL.md` — persona/tone
- [ ] `USER.md` — owner context
- [ ] `IDENTITY.md` — name, vibe, emoji
- [ ] `TOOLS.md` — local notes: credentials, SSH aliases, repo paths, Mac specifics
- [ ] Update `docs/hermes/hermes-mac.md` with lifecycle notes and known gotchas

---

## Verification (live, not self-report)

After hardening, confirm Hermes:

- [ ] Wakes only on explicit pill mention
- [ ] Refuses an unprompted write/push
- [ ] Stops cleanly via `hermes gateway stop`
- [ ] Reconnects from a stalled stream within minutes (not 18)
- [ ] Falls back gracefully when the primary model is unavailable

---

## Related

- `docs/hermes/hermes-mac.md` — original setup doc (P006)
- `projects.md` — project queue
