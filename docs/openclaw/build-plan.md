# Homelab AI Agents — Build Plan

**Date:** 2026-06-21
**Purpose:** The concrete build plan — verified system state, six steps in dependency order, and the consolidated build sequence. Companion to the concepts-reference document.

---
## Verified current state (bot-confirmed against live system)

- Config valid; Gateway active; heartbeat live at `1h`.
- `contextPruning` is configured under `agents.defaults`.
- Default chain: `openai/gpt-5.5` → `anthropic/claude-sonnet-4-6` → `google/gemini-3-flash-preview`.
- One agent: `main`. Zero routing rules.
- `claude-cli` deprioritization **already confirmed**; durable `anthropic:default` token leads.
- Live Gateway PATH includes `claude`; `claude-cli/claude-opus-4-8` probes OK.
- **Memory search broken** — embeddings quota exhausted.
- `MEMORY.md` and `memory/2026-06-21.md` **not cleanly reconciled** (daily file has duplicated/stale early entries + later corrections).

### Load-bearing secrets (verified by name)
- **Control-channel / lockout-sensitive:** `TELEGRAM_BOT_TOKEN`, `OPENCLAW_GATEWAY_TOKEN`, `gateway.auth.token`.
- **Important, less lockout-sensitive:** `GOOGLE_WEBSEARCH_API_KEY`, `OPENAI_WHISPER_API_KEY`, Anthropic default token (agent auth SQLite).
- `secrets audit` flags plaintext: `gateway.auth.token`, Google web-search key, Anthropic default token.
- **Historical residue exists** — old env backups and shell snapshots contain secret material. Migration needs cleanup/rotation, not just live-config changes.
- Doctor flags: `~/.openclaw` state dir too open (recommends `chmod 700`); a pending CLI scope-upgrade warning.

---

## Step 1 — Finish OpenClaw config (do first; it's the daily driver)

In dependency order:

1. **Reconcile memory artifacts** — `MEMORY.md` vs `memory/2026-06-21.md`. Deduplicate stale entries; make canonical state live where OC reads at boot.
2. **Write MEMORY.md routing/auth policy** — now that the chain is settled.
3. **Fix embeddings** (or switch embeddings provider) — gate semantic-memory reliance on this. Investigate which key/project backs embeddings and whether it needs isolation.
4. **`chmod 700` on `~/.openclaw`** — cheap, do early.
5. **Resolve or consciously defer the CLI scope-upgrade warning** — before relying on doctor/gateway-mediated secret tooling (the SecretRef step *uses* that tooling).
6. **History/context pruning tuning** (Task 3 Part B) — review trim threshold; real token savings live here since OpenAI is already cache-maxed.
7. **SecretRef migration — staged, last in this batch:**
   - Inventory → backup → **establish recovery path** (local shell access, config backup, known-good restart/revert command) *before* touching control-channel tokens.
   - Migrate **non-control** secrets first; verify/reload.
   - Migrate **control-channel** tokens (`TELEGRAM_BOT_TOKEN`, `OPENCLAW_GATEWAY_TOKEN`, `gateway.auth.token`) **one at a time**, last.
   - **Clean/rotate historical residue** — old env backups, shell snapshots. A rotated secret still sitting in a `.bak` isn't secured.
   - Goal: `secrets audit --check clean`.
8. **Backup automation + any other common useful configs** — flag and add.

## Step 2 — Ollama tier (own Proxmox LXC)

- Separate LXC from the OpenClaw container. Provision it generously with RAM (host has 64 GiB; LXC allocation is just a config number — the OC container's 16 GiB is irrelevant to this).
- **CPU-first.** Skip Vega 64 / ROCm-in-LXC on the first pass — not worth the complexity for ~8 GB VRAM. Pass GPU later only if a proven latency-sensitive task needs it.
- After provisioning, **confirm the container actually sees the allocated RAM** before expecting large quants.
- Goal: offload cheap tasks (heartbeat, classification) off paid models.

## Step 3 — Basic manual routing

- Manual/explicit first; **no semantic dispatcher yet.**
- **Prove Ollama before routing real traffic to it** — pass boring tests: classification accuracy, concise summaries, no hallucinated urgency, graceful failure.
- Start with explicit commands ("use Ollama for this classification") before any automation.
- Target policy: heartbeat/cheap → Ollama; long reasoning → Opus; coding → Sonnet; `main` default → OpenAI.

## Step 4 — Hermes on Mac (split; prove each sub-step before the next)

- **a.** Install + configure Hermes standalone on the Mac. (`hermes claw migrate` can import OC config as a starting point.)
- **b.** Integrate with the homelab repo — Ansible confs + the markdown docs. *The homelab repo markdown serves double duty: project documentation **and** a human/agent-readable tutorial/knowledge base. Both people and agents read it.*
- **c.** Wire OC ↔ Hermes (OpenAI-compatible endpoint or MCP bridge) so they can collaborate — after a+b are working. Don't wire two gateways together before either is proven on the task.

## Step 5 — Homelab/Proxmox maintenance agent (on Mac Hermes)

- **Lives on Mac Hermes — not on Proxmox.** OC runs *on* Proxmox, so a Proxmox agent that breaks Proxmox could take OC down (circular dependency). Mac Hermes is outside the blast radius.
- **Connects DIRECTLY to the Proxmox host via SSH** and runs tasks itself. Do **not** route Proxmox execution through OC — that re-introduces the dependency. The management plane stays independent of the managed host.
- Highest-blast-radius agent (root over the hypervisor): own workspace/auth, backup-first procedure, **read/report/propose by default with explicit approval for host mutations.**
- **Knowledge loop:** manually document hand-done setup in the homelab repo markdown → teach the agent Proxmox tasks + monitoring/maintenance → it extends the docs/knowledge base over time.

## Step 6 — Deploy Whisper via the Proxmox agent

- Last step; depends on Step 5 existing.
- Replaces the paid `OPENAI_WHISPER_API_KEY` with a local model.

---

## Consolidated dependency order

1. Reconcile memory + write routing/auth policy.
2. Fix embeddings (or switch provider) before relying on semantic memory.
3. `chmod 700`; resolve/defer CLI scope warning.
4. Context-pruning tuning.
5. Backup/recovery path established → SecretRef migration (non-control first, control-channel last, one at a time) → clean/rotate historical residue.
6. Provision + **prove** Ollama (separate LXC, generous RAM, CPU-first).
7. Manual routing, explicit before automatic.
8. Hermes standalone → homelab repo integration → OC↔Hermes bridge.
9. Proxmox agent on Mac Hermes (SSH direct, read/propose-first).
10. Whisper via the Proxmox agent.

---

*Caveat: tool versions, flags, and ecosystem details shift fast. Base actual commands on the bot's verified local syntax rather than guessed flags, and verify live process state over cached doctor reports.*
