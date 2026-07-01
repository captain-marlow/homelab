# Proxmox Docker Management — GitOps Architecture

**Status:** Approved design 2026-06-28.
**Decision:** Pull/GitOps model — two layers, two tools, one git source of truth, clean non-overlapping seam.

---

## Source of Truth

The **GitHub repo** is canonical. It lives on GitHub, on editing machines (Mac; omega when up), and Komodo Core keeps its own working copy. It does **not** live on the LXCs. The architect clone is **read-only (pull-only)** — not an editor.

---

## Layer 1 — Host (Ansible, push)

Ansible provisions each LXC:

- `pct create`, cores/RAM, ZFS datasets + bind-mounts (`/config`), Docker CE, Komodo Periphery agent, host packages/sysctls.
- Periphery is managed by a **state variable** (`komodo_periphery: present|absent`): install block runs `when: present`, removal block runs `when: absent`. Adding or removing Periphery = flip the var + re-run. No hand-teardown, no LXC rebuild.
- **Ansible never touches compose.**

---

## Layer 2 — Apps (Komodo, pull/GitOps)

- Komodo Stacks are defined from the git repo (repo + branch + compose path). Komodo Core pulls and deploys to the target host's Periphery agent, which runs `docker compose`.
- A **GitHub webhook** triggers on push: Komodo re-pulls and redeploys the affected stack. Deployment is git-triggered (your commit), not Watchtower-style upstream auto-pull.
- **Komodo never touches the LXC host.**
- Phase 2 (deferred): **Resource Sync** — all Komodo resources as TOML in git for full declarative reconcile.

---

## Where You Work

Edit on the **Mac** (control node) on a **git branch**. Push to GitHub = the trigger. Never edit in Komodo's UI (creates a second source of truth) or directly on the LXC.

---

## Update Flows

### Pure compose/image bump (common)

1. Create a branch.
2. Komodo test-stack deploys the branch to a scratch CT.
3. Validate.
4. Merge to `main` → webhook deploys to prod.

Ansible not involved.

### Host + compose change

1. Create a branch.
2. Spin a **temp LXC on Proxmox** via the Ansible baseline role (run from Mac) to test the host change.
3. Add the temp LXC to Komodo; deploy the branch stack to test the compose.
4. Validate.
5. Promote by merging:
   - Host change → Ansible `main` → re-run role against prod LXC.
   - Compose change → git `main` → webhook → prod.
6. Destroy the temp LXC.

---

## Core Principles

**Test each layer through the mechanism that ships it** — host changes via Ansible, compose changes via Komodo-from-branch. Branches are staging; the disposable LXC is where both layers meet. **Prod is only ever touched by the tool, never by hand.**

**Config-drift discipline:** every host change → Ansible role/vars; every app change → repo compose. Proof of correctness: destroy an LXC, re-run the role + Komodo deploy, get an identical working stack. Run that rebuild periodically on a throwaway CT to verify.

---

## Rebuild Safety / State Management

"Blow away the LXC" = destroy compute, **keep the ZFS data**. Three buckets:

1. **App data/config** on the durable ZFS `/config` dataset — survives rebuild automatically.
2. **Secrets generated on-box and used elsewhere** (recovery keys, registration secrets, Periphery passkey) — must be captured off-box and **re-injected by Ansible**, not regenerated.
3. **Anything living only in the container rootfs** — latent disaster; must be inventoried and either moved to `/config` or treated as Ansible-injectable.

> **Prerequisite:** D007 (secrets inventory + backup) must be done before LXCs can be treated as truly disposable. Rebuild-safety is blocked on D007.

---

## Tool Roles at a Glance

| Tool | Scope | Touches |
|------|-------|---------|
| Ansible | LXC host baseline | Host OS, Docker CE, Periphery agent, ZFS mounts |
| Komodo | App GitOps deploy | `docker compose` inside the LXC |
| Git/GitHub | Single source of truth | Everything — both Ansible vars and compose files live here |

---

## Open Items

- **Resource Sync (Komodo TOML in git):** Deferred to phase 2. Current plan: manual stack definitions in Komodo UI, reconciled via webhook.
- **D007 (secrets inventory/backup):** Prerequisite for treating LXCs as disposable. Sequenced ahead of any planned LXC rebuild.
