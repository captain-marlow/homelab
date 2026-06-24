# Ollama local-AI tier (CT172) — embeddings for OpenClaw semantic memory

**Status: live (P005 complete, 2026-06-24).** A local Ollama runner on its own Proxmox
LXC now serves embeddings for OpenClaw's semantic memory, replacing the failing
OpenAI embeddings path. CPU-only tier; GPU deferred.

---

## Why this exists

OpenClaw's semantic memory was down. Embeddings defaulted to OpenAI
`text-embedding-3-small`, but the only OpenAI credential is **Codex OAuth**, which is
entitled to chat/completions and **not** embeddings — so every embed call returned
`429 insufficient_quota`. This is an *entitlement gap*, not a rolling quota. The fix:
host an open-weight embedding model locally and point OpenClaw at it — no paid key, no
cloud dependency, fully on-LAN. (A billed OpenAI key was the deliberately-rejected
alternative: it would provision a paid dependency that this local tier makes redundant.)

Scope was kept tight: **embeddings only**. The same box is intended to later host small
chat models for cheap/high-frequency tasks (heartbeat, classification) — that is a
separate, future step, not part of P005.

---

## What was built

- **CT172 `ollama`** — Proxmox LXC, static `192.168.1.172`, Debian 13, on the same
  `proxmox_lxc_docker_host` Ansible role as Synapse/NPM/servarr (Docker + Komodo
  Periphery). Resources: **16 cores** (see Performance below), 36 GB memory ceiling,
  4 GB swap, 20 GB rootfs. Model blobs persist on the ZFS `flash` pool via
  `/config/models` (survives container/CT recreation).
- **Ollama** (`ollama/ollama`) as a docker-compose stack, **LAN-only**: the published
  port is bound to the LXC's LAN IP (`192.168.1.172:11434`), not `0.0.0.0`, and there
  is **no pfSense NAT/port-forward** for 11434. Ollama has no auth of its own; the LAN
  boundary is the control.
- **One embedding model:** `nomic-embed-text` (137M params, 768-dim, ~274 MB).

## Repo artifacts

| File | Purpose |
|------|---------|
| `config/proxmox/ansible/playbooks/provision_ollama_lxc.yml` | provision CT172 (docker-host role) |
| `config/proxmox/ansible/playbooks/deploy_ollama_stack.yml`  | idempotent deploy of the Ollama compose |
| `config/proxmox/ollama/docker-compose.yml`                  | Ollama stack (LAN-bound, models on ZFS) |

**Build sequence:** `ansible-playbook provision_ollama_lxc.yml` → `deploy_ollama_stack.yml`
→ `docker exec ollama ollama pull nomic-embed-text`.

---

## OpenClaw integration

OpenClaw treats `ollama` as a **first-class embedding provider** — no OpenAI-compatible
shim needed. The provider reads `memorySearch.remote.baseUrl` and appends **`/api/embed`**
(the newer Ollama endpoint, not `/api/embeddings`). The block added to `~/.openclaw/openclaw.json`
under `agents.defaults.memorySearch` (applies to both `main` and `architect`):

```json5
{
  provider: "ollama",
  model: "nomic-embed-text",
  remote: { baseUrl: "http://192.168.1.172:11434", batch: { enabled: false } },
  fallback: "none"
}
```

- `batch.enabled: false` — Ollama has no batch API.
- `fallback: "none"` — fail **loudly** rather than silently degrade (empty≠absence
  discipline); avoids a mixed/incompatible vector space from a second embedding model.

Applied via `openclaw config patch` (dry-run validated first), then `openclaw gateway
restart`. The vector store (`sqlite-vec`) and FTS were already healthy — only the
embedding *provider* was ever the broken link. Nothing was indexed under the old model,
so the model swap was a clean rebuild (no dimension migration: 1536→768).

**Reindex:** `openclaw memory index --force` (default agent = `main`) → **7 files,
53 chunks** indexed. The `architect` agent has 0 files **by design** (its memory is the
repo clone, no `MEMORY.md`/`memory/` dir) — nothing to index there; making it
semantically search the repo would mean adding the repo to `memorySearch.extraPaths`,
out of scope here.

---

## Verification (positive test — empty ≠ absence)

`openclaw memory search` can exit 0 with empty output after a *silent* embedding
failure, so success was confirmed positively, not by absence of error:

- `openclaw memory status --deep` → `Provider: ollama`, `Model: nomic-embed-text`,
  **`Embeddings: ready`** (the 429 is gone).
- Raw `curl /api/embed` from CT175 → real **768-dim**, numeric, nonzero vector.
- `openclaw memory search "failover chain"` → **5 ranked results** with relevance
  scores, pulled from `MEMORY.md` + the daily memory file. Not empty.

---

## Performance — the core-count finding

First reindex was painfully slow: ~7s per chunk, ~6 min for 53 chunks, and a single
`openclaw memory search` took **10.8s**. This *looked* like a runaway (CPU spiking
100→0 repeatedly, the bot "stuck typing") but was actually just the slow sequential
index build; the typing indicator was stale.

Root cause: **CPU core starvation on a hybrid CPU**, not a bad build. The container saw
full `avx2`/`avx512` (so Ollama was running its optimized build), but had only **4** of
the host's **32** threads. pve01's CPU is a **hybrid performance/efficiency-core** design,
so with only 4 cores the inference threads were likely scheduled onto slow E-cores.

Fix: `pct set 172 -cores 16` (live, no reboot; persisted in `172.conf` and in the
playbook). Result — embed latency **~7–10s → 0.06–0.89s** (superlinear in core count,
consistent with now spanning P-cores). Confirmed by OpenClaw's own timing (CPU-only —
Ollama reports `size_vram: 0`):

| metric | before (4 cores) | after (16 cores) |
|---|---|---|
| direct embed | ~7–27s* | 0.06–0.89s |
| end-to-end `memory search` (warm gateway) | 10.78s | **0.99s** (~11×) |

\* The worst initial figure (~27s) was inflated by CPU contention with the *still-running*
index build; the fair post-index baseline was 10.78s. The 0.99s end-to-end is the warm
in-gateway path — what the agent actually pays on recall. (A cold `openclaw memory search`
CLI invocation is ~3.5s, but that is Node CLI startup, not embedding, and the running
agent never pays it.)

> Open optimization (idea, not done): **pin CT172 to P-cores** via
> `lxc.cgroup2.cpuset.cpus` in `172.conf` for consistent low latency on the hybrid CPU.
> See `ideas.md`.

---

## Rollback

Reverting is a config-only change (the LXC/model can stay):

1. Restore the pre-change config: `cp ~/.openclaw/openclaw.json.bak.<timestamp> ~/.openclaw/openclaw.json`
   (timestamped backup taken before the patch), **or** unset the block:
   `openclaw config patch --stdin` with `{ agents: { defaults: { memorySearch: null } } }`.
2. `openclaw gateway restart`.
3. Memory reverts to provider `openai` (default) — which fails as before, i.e. back to
   keyword/`rg` search. To re-point elsewhere, set a different `provider`.

Tearing down the tier entirely: `docker compose -f /config/docker-compose.yml down` in
CT172, then `pct stop 172 && pct destroy 172` (destroys the model store unless the ZFS
dataset is detached first).

---

## Open items / future

- **Small chat model on this tier** — heartbeat/classification offload (build-plan Step 3).
  Models load on demand; 36 GB ceiling sized for it. Then the "architect on a local
  model" decision can be made empirically (see `ideas.md`).
- **Open WebUI** — optional browser chat front-end, once there's a chat model (`ideas.md`).
- **P-core pinning** — see Performance note above (`ideas.md`).
- **architect semantic memory over the repo** — would need `memorySearch.extraPaths`.
