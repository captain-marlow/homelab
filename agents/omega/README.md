# agents/omega

Identity files for the **omega** agent — the Mac-side read-write executor on OpenClaw
(`~/.openclaw`, loopback `:18790`). These are the **version-controlled source of truth**; on the
Mac they are **symlinked** into the agent's workspace root (`~/.openclaw/workspace/`), which is
where OpenClaw loads identity from. Edit here → push → sync poller picks it up on the next cycle,
and the live files update.

- `IDENTITY.md` — name, vibe, role.
- `USER.md` — about Master.
- `SOUL.md` — role, posture, capabilities, exec discipline.

Full build record and rationale:
[`docs/openclaw/omega-mac-agent.md`](../../docs/openclaw/omega-mac-agent.md).
