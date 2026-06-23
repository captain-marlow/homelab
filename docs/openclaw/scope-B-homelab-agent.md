# Scope B — Homelab AI-Maintenance Agent (Mac · Obsidian · Proxmox)

**Purpose:** build an AI agent that helps maintain the homelab, fed by your own documented knowledge. New, distinct effort from the gateway-hardening work (Scope A). Should live in its own Claude Project (separate memory).

**Core idea:** a documentation loop — you do tasks manually in Proxmox, write them up in Obsidian, and an OpenClaw agent reads that documentation to assist (advise first, execute later). Your verified notes are the source of truth, not a model guessing at your infrastructure.

---

## Architecture (decided this session)

OpenClaw's model, established: **gateway = the brain + execution context** (runs on a host, has that host's shell/filesystem/tools); **agent = what a gateway runs** (model + instructions + workspace + memory, configured not spawned); **client = a window** (terminal chat, web UI, Telegram — all just surfaces onto a gateway). An agent executes *on its gateway's host*.

**Chosen topology: two gateways, split by turf.**
- **LXC gateway** (existing, on Proxmox) — owns *homelab* execution. Always-on. Holds the hardened model credentials. Its agent does Proxmox/container work inside the homelab.
- **Mac gateway** (new) — owns *Mac-local* execution. Needed because some work must physically run on the Mac (e.g. **Ansible launches from the Mac**, local file tasks, convenience tasks like controlling music). A pure client can't do this — it has no execution context — which is why a real gateway on the Mac is justified.

Principle: **each gateway owns its own machine's execution; neither reaches blindly into the other.** The Mac gateway can act as a *client* to the LXC gateway (or trigger it over SSH) when it needs a homelab action.

**Cost of two gateways (go in eyes-open):** two sets of auth profiles, two memories, two configs — they don't share state automatically. Worth it for dual-machine execution, but it's a real maintenance bill.

---

## Build order (respects dependencies)

### 1. Mac ↔ LXC connection (foundational)
Connect the Mac to the homelab gateway. Whether the Mac runs its own gateway (chosen) or just a client, the first concrete step is networking the two: the LXC gateway must listen on an address the Mac can reach (not just loopback), and the Mac must point at that address + the gateway token (`OPENCLAW_GATEWAY_TOKEN` already exists in the LXC `.env`).
- **Security:** do *not* bind the gateway wide-open to the network. Scope it carefully (loopback + tunnel, or a tightly-bound interface). This is the first real security decision.

### 2. Obsidian documentation skill (read/advise mode)
Build the skill that reads your Obsidian vault and answers from it. **This is the safe, high-value core** — reading notes and *telling you* the steps is near-zero-risk and immediately useful.
- **Precondition:** the `obsidian` skill is currently **disabled** on the LXC (doctor flagged missing requirements). Resolve that first.
- Start in advise-only mode. The agent knows *how* to do tasks from your docs but doesn't execute them yet.

### 3. Teach it your tasks
Feed real notes: how you restart a container, set up an LXC, do routine maintenance. The documentation *is* the curriculum. As a bonus, the docs that teach *how* to do a task also map *which* machine/agent owns it.

### 4. Whisper LXC as first taught task (bridges to Scope A)
The Whisper build (Scope A item 1) is a natural first end-to-end test of the documented-setup loop: document the LXC build in Obsidian → that becomes the agent's first taught/executed task.

### 5. Execution rights (separate, deliberate, guardrails-first)
Only after the advise loop works, consider letting the agent *execute* homelab actions. **This needs guardrails designed before capability:** a scoped SSH user, restricted command set, dry-run-first, reversible/low-stakes actions before anything like "build an LXC." Treat hypervisor access as the high-blast-radius decision it is — one bad `pct destroy` hits every CT/VM on the box.

---

## Explicitly out of scope (for now)

- **Unified "swarm" router** — one chat that auto-delegates ("reset the Nextcloud docker" / "play playlist X" without naming the machine) to the right gateway. Interesting and coherent (would be: always-on LXC gateway as front door + one Telegram bot, Mac as a worker it delegates to, intent-routing from the documented task-map), but it's *the* hard project, not a step. **Parked by decision — not part of current plans.** Note for if revived: two independent gateways = two Telegram bots by default; a single unified chat requires building the router layer on top.

---

## What's needed to start

- New Claude Project for this scope (separate memory from Scope A).
- Add **Proxmox notes** and **Obsidian notes/vault info** to that project — not currently available; nearly every step depends on real CT IDs, storage pools, bridge names, and vault structure. Generic guesses do damage here.
- First concrete action: resolve the disabled `obsidian` skill, then stand up the Mac↔LXC connection.
