# Homelab Repo
Self-hosted homelab: Proxmox, pfSense, OpenClaw, Hermes, and the AI agents that operate them.

## How this repo is organized
Four layers, **category-first**. Planning lives at the root; everything else is one of three top-level categories, each namespaced by subject *inside* it.

```
homelab/
├── STATE.md         planning — current state of the whole homelab (read this first)
├── projects.md      planning — the master list (queue, deferred, completed)
├── ideas.md         planning — loose pool of not-yet-projects
├── config/          the thing       — actual config, per subject con
│   ├── proxmox/  pfsense/  openclaw/  hermes/
├── docs/            about the thing — knowledge-base + setup, per subject
│   ├── proxmox/  pfsense/  openclaw/  hermes/
└── agents/          acts on the thing — AI agents, their own layer (not nested in a subject)
    ├── architect/  main/  proxmox-maintenance/  ...
```

The rule in one sentence: **planning at root; then `config/` (the thing), `docs/` (about the thing), `agents/` (acts on the thing) — subject is the namespace inside each category, not a top-level dir.**

Why category-first and not subject-first (`proxmox/{config,docs,agent}`): agents must stay an independent layer. The Proxmox maintenance agent must not live with Proxmox (the fixer stays independent of what it fixes), and the architect agent plans the whole homelab, not one subject. A top-level `agents/` enforces that structurally; nesting agents per subject would fight it.

The subject name (`proxmox`, `pfsense`, `openclaw`, `hermes`, …) is the join key: the same subject can appear in `config/`, `docs/`, and `agents/`, and that lets you jump between "the config," "the docs," and "the agent" for any subject.

## The three planning files

- **STATE.md** — narrative snapshot of where everything stands *right now*. The "if you read one thing, read this" file. Rewritten to stay current.
- **projects.md** — the master list, in three sections: **queue** (active + todo, in order), **deferred** (real projects, not yet scheduled), **completed** (done, for the record). Order lives **only** in the queue line, so reordering is a one-line edit. Rows point at the relevant `docs/<subject>/` for detail.
- **ideas.md** — loose pool. Things that aren't projects yet. Promote to projects.md when they firm up.

Why three files: current-state, the ordered list, and the idea pool are three different jobs. Keeping order out of STATE.md and out of docs/ is what makes reordering cheap and keeps rationale where it belongs.

## docs/*subject*/ — two sections

- **knowledge-base/** — what the thing *is* and *why*: architecture, technical decisions, gotchas (LXC bind mounts, auth rationale, etc.). **Living** — rewritten to current truth as things change.
- **setup/** — a follow-along tutorial someone could use to stand the thing up on their own machine, with links back to knowledge-base. **Frozen-ish** — only changes when the *procedure* changes, not when the running state changes.

These two rot differently. Keep the distinction sharp: a state change updates knowledge-base; only a procedure change touches setup.

## agents/ — its own layer

Agents *act on* subjects; they aren't *part* of them. Some subjects have several agents (OpenClaw: `architect` + `main`), some have one, some none. A dedicated dir handles the uneven count and keeps a clean list.

This also reinforces a hard principle: **the thing that fixes a system stays independent of the system it fixes.** The Proxmox maintenance agent lives in `agents/`, not `config/proxmox/`, and SSHes in — never a circular dependency.

## The working loop

1. Pick the next project from `projects.md`.
2. Work it in a dedicated chat session (read STATE.md + the relevant `docs/<subject>/` first).
3. On completion: fold durable results into `docs/<subject>/knowledge-base/`, update any `setup/` tutorial if the procedure changed, mark the project done in `projects.md`, and refresh STATE.md.
4. If new info changes the plan: small reorder → edit the `projects.md` order line; real strategy shift → capture the reasoning in the relevant knowledge-base doc, then update projects.md / STATE.md.

A project isn't **done** until its result is reflected in `docs/`. (Same discipline as: a promise isn't real until a mechanism backs it.)
