# Architect Agent — read-only Opus planner (P003)

The planner half of the Matrix two-agent loop: a second OpenClaw agent (`architect`) on the
existing gateway, **read-only / deny-exec, pinned to Opus, on its own Anthropic credential**,
reading the homelab repo as its knowledge base. It plans; it never touches the system. `main`
executes; the human gates.

- **Gateway:** OpenClaw on the `openclaw` LXC (CT175, `192.168.1.175`), OpenClaw **2026.6.8**.
- **Agent id:** `architect` (second agent alongside `main`; gateway hosts multiple isolated agents).
- **Model:** `anthropic/claude-opus-4-8`, on a **dedicated Max setup-token** in the agent's own auth store.
- **Status:** Built and **proven working** (read-only, repo-grounded, Opus answering). Not yet on
  Matrix — `@architect` binding is **P004** (the loop).

The architect is co-resident with `main` on the same gateway, not a separate machine. The
"independent of the system it fixes" principle governs the *Proxmox maintenance agent* (which
mutates the host); the architect only plans, so logical isolation (own agentDir, own auth, locked
tool policy) is the right boundary.

---

## Agent definition (`openclaw.json` → `agents.list[]`)

Created with `openclaw agents add architect --agent-dir … --workspace … --model anthropic/claude-opus-4-8`
(no scope upgrade required — unlike `channels add`), then the read-only policy was edited in directly:

```json
{
  "id": "architect",
  "name": "architect",
  "workspace": "/home/openclaw/.openclaw/agents/architect/workspace",
  "agentDir": "/home/openclaw/.openclaw/agents/architect/agent",
  "model": "anthropic/claude-opus-4-8",
  "skills": [],
  "sandbox": { "workspaceAccess": "ro" },
  "tools": {
    "profile": "minimal",
    "alsoAllow": ["read", "message"],
    "deny": ["group:runtime", "write", "edit", "apply_patch"],
    "exec": { "mode": "deny" },
    "fs": { "workspaceOnly": true }
  }
}
```

**Effective tool set, confirmed live in the agent's system-prompt report: `read`, `message`,
`session_status`. No exec, no write.**

### Why this policy (least-privilege + defense-in-depth)
- `profile: minimal` grants only `session_status`; `alsoAllow: [read, message]` opens a *closed*
  allowlist of exactly read + Matrix-send. Nothing else is even offered.
- `deny: [group:runtime, write, edit, apply_patch]` is explicit belt-and-suspenders so the posture
  survives any future profile change. (`group:runtime` = `exec`, `process`, `code_execution`.)
- `exec.mode: deny` — exec subsystem off. (Note: `exec.mode` and `exec.security` are **mutually
  exclusive** — setting both fails `config validate`; `mode: deny` is sufficient.)
- `sandbox.workspaceAccess: ro` + `fs.workspaceOnly: true` — filesystem boundary: read-only, and
  reads can't escape the workspace.
- `skills: []` — no skills (a skill could smuggle in exec).

The read-only guarantee rests on this **tool policy**, not an OS sandbox (`sandbox.mode` reports
`off`). The tool allowlist is the enforcement, and it's confirmed present at runtime.

---

## Auth — its own Max token, isolated from `main`

- Per-agent auth is structural: each agent's auth store lives **inside its agentDir**
  (`~/.openclaw/agents/architect/agent/openclaw-agent.sqlite`).
- **Inheritance gotcha:** an agent with an *empty* store **inherits `main`'s** profiles. Writing a
  profile into the architect's own store (same id `anthropic:default`) **shadows** the inherited one.
- The architect runs on a **fresh Claude Max setup-token** (minted via `claude setup-token`, pasted
  with `openclaw models auth --agent architect paste-token --provider anthropic --profile-id
  anthropic:default`) — a *distinct* credential from `main`'s, independently revocable, on the Max
  subscription (chosen over a metered API key to use the Max plan; chosen over sharing `main`'s
  token for independent revocation).
- **Verified:** post-restart, `main`'s Anthropic leg still works (`pong`, no regression) and the
  architect answers on Opus via its own token (`fallbackUsed: false`, `authMode: auth-profile`).

---

## Doc-repo wiring

The architect reads the homelab repo as its knowledge base.

- **Read-only GitHub deploy key** (ed25519, `~/.ssh/architect_homelab_deploy`) under the `openclaw`
  user, registered on the repo's Deploy keys with **write access off**. Per-repo, independently
  revocable — cleaner than a PAT. Reached via an SSH host alias so it doesn't collide with other keys:
  ```
  Host github-homelab
    HostName github.com
    User git
    IdentityFile ~/.ssh/architect_homelab_deploy
    IdentitiesOnly yes
  ```
- **Clone:** `git clone git@github-homelab:captain-marlow/homelab.git
  ~/.openclaw/agents/architect/workspace/homelab`.
- **Refresh:** manual `git -C …/workspace/homelab pull` ("manual before automatic"; tighten to
  cron/webhook only if it proves annoying).
- The key must live under the **`openclaw`** user (the gateway service user that runs the agent),
  not root.

---

## Identity — curated externally, version-controlled

The architect is `workspaceAccess: ro`, so it **cannot self-bootstrap** (the normal OpenClaw flow
where an agent writes its own `IDENTITY.md`/`SOUL.md` and deletes `BOOTSTRAP.md`). That's correct —
its brief is **curated by humans**, in git:

- `IDENTITY.md`, `USER.md`, `SOUL.md` are authored in the repo at **`agents/architect/`** (the
  version-controlled source of truth) and **symlinked** into the workspace root
  (`~/.openclaw/agents/architect/workspace/IDENTITY.md → homelab/agents/architect/IDENTITY.md`, etc.).
  OpenClaw loads identity from the workspace **root**, not the cloned subdir — the symlinks bridge
  the two so a `git pull` is the only refresh step.
- `BOOTSTRAP.md` was **deleted** (it can't be completed by a read-only agent and would loop).
- **No `MEMORY.md`** — unlike `main` (which carries durable routing/auth policy), the architect's
  durable knowledge *is the repo*. `SOUL.md` (posture) + the repo it reads = its memory.
- `AGENTS.md` / `TOOLS.md` / `HEARTBEAT.md` left as scaffold defaults.

`SOUL.md`/`USER.md` encode the read-only planner role, the plan-don't-execute rule, the
read-order into the repo (STATE → projects → ideas → docs/), and Master's working style
(rigor, change-safety, own-errors-plainly, least-privilege).

---

## Verification (what was proven)

A live run (`openclaw agent --agent architect --model anthropic/claude-opus-4-8 --message …`):
- Identifies as **Architect 📐, the read-only planner** (identity files injected, confirmed in
  `injectedWorkspaceFiles`).
- `tools: [read, message, session_status]`, `skills: []` in the actual system prompt.
- Used `read` against the repo (`toolSummary: calls 2, tools [read], failures 0`) and correctly
  reported live state (P003 active, P001/P002 done, the queue order) — even surfacing an unprompted
  follow-up (back up the E2EE recovery key). The SOUL is working: grounded, not guessing.

**Deferred proof:** the run used the *embedded* runner (`infer` doesn't accept `--agent`; the
agent runner is `openclaw agent --agent …`). The **through-the-live-gateway** proof comes in P004,
when `@architect` is Matrix-bound and reachable end-to-end.

---

## Gotchas (hard-won)

- **`agents add` needs no scope upgrade** — unlike `channels add`/`secrets.*`, which hit the
  `operator.read` wall. Agent config writes go through the CLI fine.
- **`infer model run` has no `--agent`** — use `openclaw agent --agent <id> --model … --message …`
  to exercise a specific agent (runs *embedded*, not gateway-transport).
- **`exec.mode` ⊕ `exec.security`** — mutually exclusive; `config validate` rejects both. Use
  `mode: deny`.
- **Per-agent auth inheritance** — an empty agent store silently inherits `main`'s; write the
  agent's own profile to shadow it.
- **User matters** — all OpenClaw state is under the `openclaw` user (`/home/openclaw/.openclaw`),
  not root. Run as `openclaw` (direct SSH login, not `su` — `systemctl --user` needs the real
  session). A stray deploy key created under root had to be regenerated under `openclaw`.
- **Token handling** — a setup-token was once pasted into a chat transcript and had to be rotated.
  Secrets go into the box terminal only, never into a chat.
- **Origin was stale** — GitHub `origin/main` was 3 commits behind local (the migration + P001/P002
  were never pushed); the architect first cloned a pre-migration snapshot. Pushed, then re-pulled.

---

## Operations

- **Refresh the architect's repo:** `git -C ~/.openclaw/agents/architect/workspace/homelab pull`
  (as `openclaw`). Identity symlinks pick up changes automatically.
- **Edit the architect's identity:** edit `agents/architect/*.md` in the repo → push → `git pull`
  on the box (symlinks resolve to the new content).
- **Re-probe:** `openclaw agent --agent architect --model anthropic/claude-opus-4-8 --message '…' --json`
  — check `injectedWorkspaceFiles`, `tools`, and `toolSummary`.
- **Restart after config edits:** `openclaw config validate && openclaw gateway restart` (interrupts
  `main`'s in-flight turn).

---

## P004 — DONE (the two-agent loop is live)

`@architect` is bound on Matrix and the mention-gated loop room (**Drafting Table**) is verified
live. Full record: **`docs/openclaw/two-agent-loop.md`**. Highlights / deviations from the plan
above:

- **Additive, not a relocation.** `@openclaw` stayed the implicit top-level `default` account
  (token + E2EE store untouched); only `accounts.architect` was added. The plugin connects the
  `accounts{}` map *plus* the implicit default, so a relocation was unnecessary and riskier — see
  the two-agent-loop doc for the code-level reasoning.
- **`openclaw agents bind --agent architect --bind matrix:architect`** wrote the top-level
  `bindings[]` route with **no scope wall** (unlike `channels add`).
- **Token minted via `localhost:8008` on CT171**, not the public URL — Synapse rejects
  password-login through the public URL (403), a hard-won finding (the bot creds file was *not*
  stale). Token then `scp`'d to the CT175 SecretRef file.
- **Gate:** `channels.matrix.rooms["!FKZTkwAIkROBtdHyCl:…"]` with `allowBots:"mentions"` +
  `requireMention:true` (channel-level, applies to both accounts), `botLoopProtection` on.
- The deferred **gateway-path proof** is now closed — `@architect` answers live through the
  gateway transport.
