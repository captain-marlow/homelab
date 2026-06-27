# Heartbeat-hybrid (D005) — deferred design record (2026-06-27)

**Status:** DEFERRED by Ryan 2026-06-27. Design complete and validated
offline; implementation deferred because no real heartbeat workload exists yet
to justify the build (`HEARTBEAT.md` is inert). This matches D005's original
"build once there's a mixed task list to route" note.

## Goal

Route heartbeat triage to a local model primarily for **fault isolation**, not
cost. Background automation should not be able to drain the metered cloud rail
or starve interactive use if it loops or gets noisy. The current heartbeat
baseline is near zero because no active heartbeat checks are configured, and
even a cloud heartbeat would likely be low single-dollar monthly spend.

OpenClaw does not currently provide a built-in semantic router for this shape;
role routing is a dispatcher/pipeline we would build.

## Offline Validation

All validation below was offline only. No live heartbeat config,
`HEARTBEAT.md`, cron job, or OpenClaw router setting was changed.

- CT172 (`192.168.1.172:11434`) is CPU-only with 16 cores and 36 GB RAM.
- Existing embedding model: `nomic-embed-text:latest`.
- Added chat models during validation:
  - `qwen2.5:3b` (~2 GB loaded), reports `completion` + `tools`.
  - `qwen2.5:7b` (~5 GB loaded), reports `completion` + `tools`.
- Latency:
  - `qwen2.5:3b`: about 3 tok/s in direct CPU tests.
  - `qwen2.5:7b`: soft-triage calls around 10–15 seconds, acceptable for an
    hourly background job.
- 18-case labeled bake-off, weighted toward urgent and ambiguous scenarios:
  - Sonnet baseline: 18/18, 0 must-surface misses.
  - `qwen2.5:3b` with urgency prompt: 16/18, 2 must-surface misses; failed
    acceptance.
  - Deterministic rules + `qwen2.5:7b`: 18/18, 0 misses, 0 false positives;
    passed offline acceptance.
- `qwen2.5:3b` tool-calling smoke test: 10/10 valid structured tool calls.

## Locked Design

### Production Home

Use a **scheduled cron command job / plugin service**, not OpenClaw's
model-driven heartbeat turn.

OpenClaw heartbeat is model-driven by design: `heartbeat.model` swaps which
model drives the turn, but does not make deterministic code the orchestrator.
The only heartbeat-adjacent hook that can short-circuit a turn is
`before_agent_reply`; that remains a possible integration tool, but not the
primary safety boundary.

The safer production shape is:

```text
cron every 1h
  -> gather signals
  -> normalize structured Signal[]
  -> deterministic must-surface rules
  -> qwen2.5:7b for ambiguous remainder only
  -> NO_REPLY or one concise alert
```

The model is a subroutine. It never decides whether the safety rules run.

### Signal Flow

1. **Gather**: read the configured signal sources, such as calendar, email, and
   Matrix/direct mentions.
2. **Normalize**: convert raw provider data into deterministic metadata:

   ```ts
   type Signal =
     | {
         kind: "calendar";
         startsAt: string;
         minutesUntilStart: number;
         title: string;
         changed?: boolean;
       }
     | {
         kind: "message";
         channel: "matrix" | "slack" | "email";
         senderRole?: "boss" | "family" | "architect" | "service" | "unknown";
         directMention: boolean;
         requiresAction: boolean;
         flags: string[];
       }
     | {
         kind: "system";
         source: "github" | "security" | "bank";
         severity: "info" | "warning" | "urgent";
         requiresAction: boolean;
       };
   ```

3. **Rules**: force-surface catastrophic categories using structured metadata:
   - calendar event starts within about 2 hours;
   - calendar event is moved into that window;
   - key sender plus action/important/urgent metadata;
   - direct mention requiring action;
   - security, payment, account-action, production, or deploy-failure flags.
4. **Soft triage**: send only ambiguous leftovers to `qwen2.5:7b`.
5. **Decision**:
   - print `NO_REPLY` for quiet;
   - print one concise alert for surface;
   - fall back to cloud triage on CT172/Ollama failure, qwen timeout, or invalid
     JSON.

`HEARTBEAT.md` stays inert to avoid double-running the model-driven heartbeat
and the cron-owned hybrid.

### Safety Invariant

Must-surface recall is deterministic via rules, never model judgment. The
critical path is deterministic normalization of sender role, event-time math,
and provider flags.

The offline rule bug where `"no urgent email"` matched raw `"urgent"` is the
reason production rules must operate on structured fields instead of substring
matching.

### Fallback and Revert

- Cloud fallback: use Sonnet if CT172/Ollama is unreachable, times out, or
  returns invalid JSON.
- Never silently drop a heartbeat-equivalent run.
- Revert is disabling the cron job. No live heartbeat model override is needed
  for the deferred design.

## Deferred Because

Ryan deferred D005 on 2026-06-27. There is currently no active heartbeat workload
to route, so the correct next state is to keep the design record and revisit
when a real mixed task list exists.
