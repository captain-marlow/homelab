# Homelab AI Agents — Concepts Reference

**Date:** 2026-06-21
**Purpose:** The concepts learned while planning a homelab agent setup: what agents, gateways, and the connecting protocols actually are. Companion to the build-plan document.

---

## 1.1 Models vs. agents

A **model** (Sonnet, Opus, GPT) is text-in, text-out. Chatting in the browser or app is talking to a model turn by turn, with no loop and no tools acting on their own.

An **agent** wraps a model in a **reason → act → observe → repeat** loop and gives it **tools**. The model is the brain, the tools are the hands, the loop lets it work toward a goal instead of replying once. A chatbot tells you how to fix a bug; an agent reads the code, edits the file, runs the tests, sees them pass, and reports back.

Useful test for "is this really an agent": can it take an action, look at the result, and decide the next action on its own? If yes, it's an agent. If it answers in one shot, it's a chatbot with a fancier label.

## 1.2 The four cases (confirmed mental model)

1. **Browser/app chat** = talking to a model (Sonnet/Opus) message by message. No loop.
2. **Claude Code / Codex** = an agent: a coding harness wrapping a model in a loop with coding tools (repo reading, file editing, command running).
3. **OpenClaw** = an agent on a loop too, but model-agnostic — it drives whatever model you point it at (incl. Sonnet/Opus).
4. **Claude Code as an ACP worker in OC** = OC driving the *real* Claude Code over the ACP protocol. Functionally **no difference** from "real" Claude Code, because it *is* real Claude Code, remote-controlled. Contrast with "use a Claude model inside an OC agent," which is an *approximation* — OC's loop doing coding with a Claude brain, but not Claude Code's actual harness.

So: model-in-OC = approximation of a coding agent; ACP worker = the genuine article.

## 1.3 Two categories of agent

- **Coding agents** — terminal/IDE tools for writing/editing/reviewing code. OpenCode, Claude Code, Codex, Cursor, Gemini CLI.
- **Assistant / gateway agents** — always-on agents on a server, reachable from chat apps (Telegram, etc.), often *driving* a coding agent underneath. OpenClaw, Hermes.

## 1.4 Which models coding agents use

Coding agents are mostly model-agnostic harnesses but gravitate to frontier models strong at tool-calling and long-horizon coding. **Claude Code** defaults to Claude (Sonnet as the workhorse, Opus for heavier reasoning). **Codex** uses OpenAI models. **OpenCode** is bring-your-own-provider (people point it at Claude, GPT, or Gemini). Pattern: vendor CLIs use their own models; open ones let you choose, and most pick a frontier model.

## 1.5 The three protocols (how things connect)

- **MCP (Model Context Protocol)** — connects an agent to **tools**. The other end is a *server* exposing capabilities (filesystem, GitHub, database, web search). An **MCP client** lives inside the agent and consumes those tools. Naming is counterintuitive: "client" = the agent-side software, not the human. Transports: *stdio* (local subprocess) or *HTTP* (remote). "USB-C for AI tools."
- **ACP (Agent Client Protocol)** — connects an agent to **another agent**. The other end is a full coding agent with its own loop (Claude Code, Codex, OpenCode). Originated in the editor world (Zed et al.) so editors could drive any coding agent through one interface. OpenClaw uses it (via `acpx`) from the other direction — the gateway driving a coding agent as a worker.
- **OpenAI-compatible endpoint** — lets anything drive a gateway as if it were a model (`/v1/chat/completions`). This is the cleanest way for one gateway to call another.

Compact: **MCP gives an agent tools; ACP lets an agent drive another agent; an OpenAI-compatible endpoint lets anything drive the gateway as a model.** Three seams, three jobs.

**Trust caveat (applies to MCP servers especially):** a server can run shell commands, read files, or hit external services on the agent's behalf. Connecting one is a real security decision, the same as installing any software with those permissions, especially community-published ones.

## 1.6 OpenClaw architecture (two tiers)

```
Tier 1 — GATEWAY (one process, the switchboard)
  owns: channels, sessions, routing
  job:  inbound message -> decide which agent handles it
  |
  +-- Tier 2 — AGENT(S) (gateway can host several; isolated)
        each: own workspace, own SOUL.md/AGENTS.md identity,
              own sessions+memory, own model/skills/tools
        |
        +-- INSIDE one agent: a model in a reason-act-observe loop,
              equipped with skills (SKILL.md), tools, MCP servers
```

"OC runs multiple agents" is **both/and**: the Gateway controls multiple agents, *and* each agent is one brain with many skills/tools/MCPs. Current setup = one agent (`main`).

## 1.7 Routing — what's automatic vs. what isn't

OpenClaw automates **mechanical** routing: model fallback chains and channel/account bindings. It does **not** automate **semantic** routing ("this is hard → Opus," "this is repo work → Claude Code"). That judgment must be encoded as a **dispatcher skill** where the model reads the task and chooses. There is no built-in semantic router.

Three routing layers:

1. **Hard routing** — channel/account/session bindings (source determines agent). Reliable but coarse.
2. **Manual per-task** — you say "use Opus for this." Flexible, low-risk.
3. **Semantic dispatcher** — `main` classifies a mixed task list and delegates. This is a skill you build, not a feature you toggle.

## 1.8 Hubs

There is **no OpenClaw agent marketplace.** ClawHub is a skills/plugins hub. Agents are local configs (workspace, identity, model, bindings, skills, auth) you assemble yourself. Community `SOUL.md` templates exist to copy, but agents aren't "installable."

## 1.9 Guiding principles that emerged

- **Finish the foundation before adding tools.**
- **Prove a cheaper/independent tier works before routing real traffic to it.** A local model failing silently is worse than paying for a reliable one. (Mirrors the reference-doc lesson: a configured-but-dead fallback creates false confidence.)
- **The thing that fixes a system must stay independent of the system it fixes.** (Why the Proxmox agent lives on Mac/Hermes and SSHes in directly — not through OC, which runs *on* Proxmox.)
- **Verify the live process, not a cached report.** (`doctor` output reflects its environment at run-time, not necessarily the running Gateway. Auth-present ≠ works; works-embedded ≠ works-through-gateway.)
- **Don't over-provision agents.** One coordinator + specialists that are actually needed.

---
