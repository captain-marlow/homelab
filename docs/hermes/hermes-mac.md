# Hermes on the Mac — Mac-side read-write / git-push executor (P006)

**Status: P006 in progress.** Step **a** (standalone) and step **b** (repo integration) are
**DONE and verified (2026-06-24)**. Step **c** (into the Matrix loop) is **not started** and has a
newly-found macOS blocker (see below). This is the institutional version of the role Claude Code
plays manually now — the Mac is the read-write executor + git-push node. Hermes is a hard
dependency for **P008** (docs sort pass needs a central read-write executor; the architect is
pull-only, `@openclaw` write is deferred).

- **Host:** this Intel Mac (x86_64, macOS 14.8). Hermes CLI is supported on Intel; the desktop app
  is Apple-Silicon-only (we use the CLI).
- **Version:** Hermes Agent v0.17.0 (2026.6.19). `HERMES_HOME=~/.hermes`; command at
  `~/.local/bin/hermes`; code at `~/.hermes/hermes-agent` (uv-managed Python 3.11 venv).

---

## a. Standalone — install + auth

**Install:** the official `install.sh` was downloaded and **reviewed before running** (no blind
pipe). It is clean: unsets inherited `PYTHONPATH/PYTHONHOME`, two-stage downloads, and installs
Python deps via **`uv sync --extra all --locked`** (hash-verified — rejects any transitive whose
SHA doesn't match the lockfile). On this Mac it reused the system Node 24, rg, and ffmpeg; no
`sudo`. Browser tools (Playwright Chromium) included. 72 bundled skills seeded into
`~/.hermes/skills/`. `hermes doctor` is green.

**Migrate from OpenClaw — skipped (deliberate).** The Mac's `~/.openclaw` was a **stale March
`2026.3.13` local shell** (iMessage/LINE channels, single Sonnet model, plaintext keys), **not** the
CT175 daily-driver. `hermes claw migrate --dry-run` confirmed it would import ~nothing (`no model
providers found`). The rich config lives on CT175, and its auth (Codex OAuth / Max setup-token /
file SecretRefs) doesn't transplant anyway — so we configured Hermes directly. **The March Mac
OpenClaw install was then deleted** (`~/.openclaw` + the pnpm `openclaw` package; pnpm itself left
intact). Its plaintext keys (gateway token, 2× Gemini, 2× OpenAI `sk-proj`) should be **rotated** —
they sat unencrypted (now only in a session-scratch backup tarball).

**Auth — native PKCE OAuth, on the Max plan.** Hermes runs **`anthropic/claude-sonnet-4-6`** via
its **own native PKCE OAuth** credential (`hermes auth add anthropic --type oauth` → source
`hermes_pkce`, its own client_id), on the Max subscription. Provider `anthropic`, set in
`~/.hermes/config.yaml`. Verified: a one-shot ping returns `pong`, fast, with **no** Claude Code
logout.

> **Hard-won gotcha — Hermes auto-pools Claude Code's credentials.** Hermes auto-discovers every
> Anthropic credential on the machine and seeds a **rotation pool** (`hermes auth list`). On this
> Mac that pool included a `claude_code`-source entry that reads the **live VS Code Claude Code
> session token** (`~/.claude/.credentials.json` / Keychain). Hermes rotating to / using it
> **repeatedly logged the user out of Claude Code** and made calls **hang** (live token invalidated
> mid-flight → retry → toward the 30-min `HERMES_API_TIMEOUT`). It was **not** token-value sharing
> (the `.env` setup-token was freshly minted and distinct) and **not** the Claude-Code impersonation
> per se (native PKCE impersonates identically — `claude-code` UA + "You are Claude Code" system
> prefix, gated on `_is_oauth_token` — yet does **not** bump the session). The trigger was Hermes
> **using the auto-pooled `claude_code` credential**.
>
> **Fix (verified):** `hermes auth list` → `hermes auth remove anthropic <label>` the `claude_code`
> entry **and** any stale `CLAUDE_CODE_OAUTH_TOKEN` env entry (removal "suppresses" them — they
> won't re-seed). Leave the pool with **only** `hermes_pkce`.
>
> **Footgun:** never run bare **`hermes auth add anthropic`** — it re-discovers and re-pools the
> `claude_code` creds. An `sk-ant-api` key avoids the OAuth/impersonation path entirely (it's
> excluded from `_is_oauth_token`) if a fully clean separation is ever wanted.

---

## b. Repo integration — the executor role (proven)

Hermes operates on its **own clone**, separate from Claude Code's working clone (one writer per
working tree).

| Thing | Value |
|---|---|
| Hermes clone | `~/Developer/homelab-hermes` (sibling of Claude's `~/Developer/homelab`) |
| Push auth | **dedicated read-write deploy key** `~/.ssh/hermes_homelab_deploy`, SSH alias `github-hermes`, registered on the repo's GitHub **Deploy keys with write access** |
| Commit identity | `Hermes <hermes@ryankennedy.dev>` (local to the clone) |
| `terminal.cwd` | `~/Developer/homelab-hermes` (so the **headless** executor — gateway/cron — defaults to the repo) |

The deploy-key pattern mirrors the architect's (CT175) but **read-write**; a repo can hold both
(architect = read-only, Hermes = read-write). Independently revocable, least-privilege, auditable.

**Acceptance test — PASSED.** Hermes (run headless: `hermes -z "<task>" --cli --yolo`) added a real
one-line idea to `ideas.md`, committed as `Hermes`, and pushed to `origin/main` (commit `4f5c082`).
**Independently verified** (not the agent's self-report): `git ls-remote` shows `origin/main ==
4f5c082`, author `Hermes`, only `ideas.md` changed. Then the **other two clones were refreshed** —
Claude's working clone (`git pull --ff-only`) and the architect's on CT175
(`ssh openclaw '… git pull --ff-only'`).

**Three clones now exist** (was one): Claude's working clone, **Hermes's read-write clone**, and the
architect's read-only clone on CT175. **Post-push discipline:** origin is the single source of
truth; after any push (by anyone), refresh the other clones. Git is still authored by both Claude
and Hermes now — distinguish by commit author.

**Adjacent Ansible work** tagged to this track (open, lower priority, see `ideas.md`): auto-register
new LXCs in `~/.ssh/config`; an LXC baseline-hardening role.

---

## c. Into the loop — NOT started, with a macOS blocker

The plan: a fresh `@hermes` Synapse account bound into **Drafting Table**
(`!FKZTkwAIkROBtdHyCl`), mention-gated, as the Mac-side executor alongside `@openclaw`.

**Hermes has native Matrix support** — `plugins/platforms/matrix/adapter.py`, mention-gating
(`tests/gateway/test_matrix_mention.py`), via **`mautrix[encryption]`**. **But the blocker:** the
`matrix` extra pulls **`python-olm`, which pyproject notes has "no native build path on modern
macOS."** The Drafting Table room is **E2EE**, so a non-encrypted Matrix client can't read it. So
**Mac-side Hermes may not be able to join the encrypted room at all.**

**P006c must first resolve this** — open options (decide next session, plan with the architect):
1. Test whether `mautrix`/`python-olm` actually installs on this Intel Mac (pyproject implies no).
2. If not: use the **OC ↔ Hermes bridge** instead of direct Matrix (build-plan Step 4c: an
   OpenAI-compatible endpoint or **MCP** — Hermes can both serve and consume MCP: `hermes mcp serve`
   / `hermes mcp add`), so `@openclaw`/architect reach Hermes without Hermes joining Matrix.
3. Or an unencrypted side-room, or run Hermes's Matrix gateway off-Mac (defeats Mac-side intent).

**Also still open for P006c:**
- **Division of labor** between the two executors — `@openclaw` (cluster-side) vs Hermes (Mac-side
  read-write/git-push). architect plans → Ryan gates → *which executor applies?* Plan with the
  architect.
- **Token caveat (known):** mint any `@hermes` Synapse token via **`localhost:8008` on CT171** — the
  public URL rejects password-login (403). Do **not** reuse `@openclaw`'s token.
- **Memory:** optionally point Hermes at the **CT172 Ollama** tier (`192.168.1.172:11434`,
  `nomic-embed-text`) for semantic memory — reuse, don't rebuild.

---

## Operations / quick reference

- **Run interactively:** `hermes` (TUI) or `hermes --cli`. Headless one-shot: `hermes -z "<task>"`.
- **Headless autonomous executor:** `hermes -z "<task>" --cli --yolo` (auto-approves tool calls for
  a scoped task; run from inside the clone, or rely on `terminal.cwd`).
- **Health:** `hermes doctor`, `hermes status`, `hermes auth list` (confirm pool = `hermes_pkce`
  only), `hermes config show`.
- **Push as Hermes:** the clone's remote is `git@github-hermes:…`; the deploy key authenticates.
  After a Hermes push, refresh Claude's clone (`git -C ~/Developer/homelab pull --ff-only`) and the
  architect's (`ssh openclaw '… git pull --ff-only'`).
- Config: `~/.hermes/config.yaml` (model/provider/terminal.cwd/toolsets — Context Engine tool
  enabled). `~/.hermes/.env` (the old `CLAUDE_CODE_OAUTH_TOKEN` line is **disabled**; PKCE creds are
  pooled, not in `.env`).
