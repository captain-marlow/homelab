# agents/architect

Identity files for the **architect** agent — the read-only Opus planner on the OpenClaw gateway
(CT175). These are the **version-controlled source of truth**; on the box they're **symlinked**
into the agent's workspace root (`~/.openclaw/agents/architect/workspace/`), which is where
OpenClaw loads identity from. Edit here → push → `git pull` on the box, and the live files update.

- `IDENTITY.md` — name / vibe / what it is.
- `USER.md` — about Master.
- `SOUL.md` — role and posture: read-only, plan-don't-execute, how to read the repo.

Full build record and rationale: [`docs/openclaw/architect-agent.md`](../../docs/openclaw/architect-agent.md).
