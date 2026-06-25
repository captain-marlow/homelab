# Hermes on the Mac — Mac-side read-write / git-push executor (P006)

**Status: P006 COMPLETE.** Steps **a** (standalone), **b** (repo integration), and **c** (into the
Matrix loop) are all **DONE and verified (2026-06-24/25)**. `@hermes` is a live, E2EE, mention-gated
participant in the Drafting Table room alongside `@openclaw`/`@architect`. This is the institutional
version of the role Claude Code plays manually now — the Mac is the read-write executor + git-push
node. Hermes is a hard dependency for **P008** (docs sort pass needs a central read-write executor;
the architect is pull-only, `@openclaw` write is deferred).

> **The "macOS blocker" was Apple-Silicon-specific, not "modern macOS."** Hermes's pyproject and our
> earlier notes said `python-olm` had "no native build path on modern macOS." The **official Hermes
> Matrix doc** is more precise: the `[matrix]` extra is gated to Linux "due to libolm compilation
> issues **on Apple Silicon**." This is an **Intel (x86_64)** Mac, so the build works fine once
> `libolm` is present (proven end-to-end below). Lesson logged: read the vendor docs first.

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

## c. Into the loop — DONE (direct E2EE Matrix, mention-gated)

`@hermes` is a fresh non-admin Synapse account (parallel to `@openclaw`/`@architect`) joined into
**Drafting Table** (`!FKZTkwAIkROBtdHyCl`), reading/replying over **E2EE**, **mention-gated**. We
took the **direct-Matrix** path (not the MCP bridge) once the blocker proved Intel-surmountable.

### Dependency build — libolm + the matrix extra (Intel Mac)

`mautrix[encryption]` needs **`python-olm`**, which binds the C library **libolm**. python-olm's
sdist tries to build libolm from source via CMake and fails on modern CMake (`cmake_minimum_required
< 3.5` removed — Hermes issue #4178). The fix is to install libolm **first** so python-olm only
compiles its cffi bindings against it:

```bash
brew install libolm            # 3.2.16 — DEPRECATED upstream & disabled in brew (2025-08-03),
                               #   but still pours from the existing bottle. EOL crypto; see caveat.
# matrix deps into Hermes's own venv (~/.hermes/hermes-agent/venv), libolm-linked:
export VIRTUAL_ENV=~/.hermes/hermes-agent/venv CFLAGS=-I/usr/local/include LDFLAGS=-L/usr/local/lib
~/.hermes/bin/uv pip install "mautrix[encryption]==0.21.0" aiosqlite==0.22.1 asyncpg==0.31.0 aiohttp-socks==0.11.0
```

These are exactly the specs Hermes's **lazy installer** (`tools/lazy_deps.py` → `platform.matrix`)
would install on first channel use; pre-installing just makes it a controlled, verified step. Verify:
`python -c "import mautrix, olm; from mautrix.crypto import OlmMachine"`. **Caveat:** libolm is EOL
(deprecated, disabled in brew) — acceptable here but the reason the direct path is a tradeoff vs the
(unused) MCP bridge; revisit if libolm ever stops pouring or on a move to Apple Silicon.

### Account + token (cluster-side, Ryan executes)

`@hermes` created with `register_new_matrix_user --no-admin` on CT171; token minted by
password-login against **`localhost:8008`** (the public URL 403s on password-login — known P004
finding). Device id **`hermes`** (re-minted from an initial `hermes-mac`; do it *before* first
gateway start so no E2EE store is orphaned). The stale `hermes-mac` device/token is a harmless
orphan — delete from Element → Sessions when convenient.

### Config — all env-driven in `~/.hermes/.env` (the channel activates on these)

```
MATRIX_HOMESERVER=https://matrix.ryankennedy.dev   # token-auth works via the public URL
MATRIX_USER_ID=@hermes:matrix.ryankennedy.dev
MATRIX_ACCESS_TOKEN=<minted on CT171; 600 file only, never committed>
MATRIX_E2EE_MODE=required
MATRIX_RECOVERY_KEY_OUTPUT_FILE=/Users/ryan/.hermes/matrix-hermes-recovery-key.txt
MATRIX_RECOVERY_KEY=<pinned after first-start bootstrap, for stable restarts>
MATRIX_REQUIRE_MENTION=true
MATRIX_THREAD_REQUIRE_MENTION=true     # ← critical; see "gating traps" below
MATRIX_AUTO_THREAD=false               # flat replies, parity with the other bots
MATRIX_ALLOWED_USERS=@ryan:…,@openclaw:…,@architect:…   # the bots MUST be listed to hand off (see "loop handoff")
MATRIX_ALLOWED_ROOMS=!FKZTkwAIkROBtdHyCl:matrix.ryankennedy.dev
MATRIX_HOME_ROOM=!FKZTkwAIkROBtdHyCl:matrix.ryankennedy.dev   # NOT _HOME_CHANNEL; silences the "no home channel" nudge
```

Start the gateway: `hermes gateway` (or `hermes gateway restart` to reload after edits — it holds a
PID lock, so plain `pkill` is the wrong tool). On first start with `E2EE_MODE=required`, Hermes
bootstraps cross-signing for the fresh device and **writes a recovery key** to the output file
(0600). **Backed up off-box** to `~/homelab-secrets/matrix-hermes-recovery-key.txt` and pinned via
`MATRIX_RECOVERY_KEY`. Auto-join works (`_on_invite` + a sync-reconciliation pass — more robust than
OpenClaw's finicky encrypted-invite path): `@ryan` invites `@hermes` from Element and it joins.
**Auth-pool stayed `hermes_pkce`-only throughout** — running the gateway did not re-pool Claude Code
creds.

### Gating traps (both hit live, both fixed) — Hermes ≠ OpenClaw

The brake (respond only when addressed) needed two fixes the OpenClaw gate didn't:

1. **Auto-thread defeats the mention gate.** Hermes defaults `MATRIX_AUTO_THREAD=true`; once it
   replies in a thread, follow-ups land "in a bot thread" and `_on_message` **bypasses
   `require_mention`** unless `MATRIX_THREAD_REQUIRE_MENTION=true` (the adapter's own
   multi-agent-room safeguard, default off). Symptom: Hermes answered a non-mention. Fix: the two
   env lines above (`AUTO_THREAD=false` + `THREAD_REQUIRE_MENTION=true`).
2. **Bare-name matching.** `_is_bot_mentioned` treated the literal word "hermes" anywhere in a
   message as a mention (a `\bhermes\b` regex branch) — looser than `@openclaw`/`@architect`, which
   need a real pill / full MXID. **No config to disable it**, so we applied a **tracked vendor
   patch**: removed the bare-localpart branch in `plugins/platforms/matrix/adapter.py`
   (`_is_bot_mentioned`), leaving the MSC3952 `m.mentions` pill, full-MXID-in-body, and
   `matrix.to/#/<mxid>` triggers. **Re-apply after any Hermes upgrade** (backup:
   `adapter.py.bak-p006c-*`; the edit carries a `HOMELAB PATCH (P006c)` comment). With both fixes,
   verified live: bare "hermes" → silence; a real `@hermes` pill → flat reply.

### Loop handoff — addressed-message model (Hermes has no `contextVisibility`)

**Hermes only ingests messages addressed to it.** Unlike OpenClaw, which separates *responding*
(needs a mention) from *reading* (`contextVisibility:"all"` records all room traffic), Hermes's
`require_mention` gate **drops** non-addressed messages *before they're recorded* — there is no
passive-room-context knob (`fetch_history` exists but has no automatic caller). So `@hermes` cannot
"see" undirected room chatter; it sees only what's pilled to it. Verified live: it could not quote
back a plain (non-pill) message from `@architect`.

This does **not** block the loop — the planner→executor handoff is *directed*, and works both ways:

- **Planner → Hermes:** the planner must emit the **full MXID** `@hermes:matrix.ryankennedy.dev`
  (which the gateway converts to a real `m.mentions` pill). A **bare `@hermes`** is inert text and
  reaches nothing — exactly the OpenClaw finding. **Verified:** `@openclaw`'s full-MXID pill woke
  Hermes and got an answer; `@architect`'s bare-text attempt did not. *The sender must also be in
  `MATRIX_ALLOWED_USERS`* — that's why the bots were added to the allowlist (the actual enabler for
  bot-to-bot handoff; the "blindness" above is the separate, accepted architectural limit).
- **Hermes → Planner:** Hermes replies in plain room text; the planners *do* see it (they have
  `contextVisibility:"all"`), so Hermes need not pill back unless it wants the planner to *act*.

**Open (division-of-labor pass with the architect):** the architect must learn to emit the full
MXID when handing off (a SOUL/convention matter, like `@openclaw` already does), and we decide which
executor (`@openclaw` cluster-side vs `@hermes` Mac-side read-write/git-push) applies what.

### Still open (non-blocking)

- **Division of labor + architect handoff habit** — see "Loop handoff" above: decide which executor
  (`@openclaw` vs `@hermes`) applies what, and get the architect emitting full-MXID pills. Plan with
  the architect. (`MATRIX_ALLOWED_USERS` already includes both bots.)
- ~~Gateway is a manual `nohup` process~~ **DONE** — installed as a **launchd LaunchAgent**
  (`~/Library/LaunchAgents/ai.hermes.gateway.plist`, `RunAtLoad` + `KeepAlive`): starts at login,
  auto-restarts on crash. Logs at `~/.hermes/logs/gateway.log`. Verified the launchd-started gateway
  **verifies cross-signing via the recovery key** (no re-bootstrap) — the `MATRIX_RECOVERY_KEY` pin
  is doing its job. (LaunchAgent = starts at *login*, not boot-before-login; `--system` is Linux-only
  and would run as root, breaking the user-context PKCE auth, so we use the user LaunchAgent.)
- **Title-generator 401** — `Title generation failed: 401 Missing Authentication header` in the log;
  cosmetic (session auto-naming), non-blocking.
- **Memory:** optionally point Hermes at the **CT172 Ollama** tier (`192.168.1.172:11434`,
  `nomic-embed-text`) for semantic memory — reuse, don't rebuild.
- **Loose secret:** `~/.hermes/.env` still carries a commented-but-plaintext `CLAUDE_CODE_OAUTH_TOKEN`
  (line `#DISABLED-collides-with-ClaudeCode …`); inert, but scrub/rotate with the other March keys.

---

## Operations / quick reference

- **Run interactively:** `hermes` (TUI) or `hermes --cli`. Headless one-shot: `hermes -z "<task>"`.
- **Headless autonomous executor:** `hermes -z "<task>" --cli --yolo` (auto-approves tool calls for
  a scoped task; run from inside the clone, or rely on `terminal.cwd`).
- **Health:** `hermes doctor`, `hermes status`, `hermes auth list` (confirm pool = `hermes_pkce`
  only), `hermes config show`.
- **Matrix gateway (launchd-managed):** runs as the `ai.hermes.gateway` LaunchAgent. `hermes gateway
  status`; `hermes gateway restart` reloads after `.env` edits (it holds a PID lock — `pkill` won't
  take); `launchctl list | grep hermes` to confirm the job; logs at `~/.hermes/logs/gateway.log`.
  `hermes gateway uninstall` removes the LaunchAgent. All Matrix config is in `~/.hermes/.env`
  (`MATRIX_*`).
- **Post-upgrade acceptance test (do this after EVERY Hermes upgrade).** The pill-only gate depends
  on a vendor patch + an EOL libolm, and both fail **silently** — bare-name matching quietly returns,
  or the channel lazy-reinstalls unpatched. So after `hermes` updates, before trusting the loop:
  1. Re-apply the `_is_bot_mentioned` patch (`HOMELAB PATCH (P006c)`; backup `adapter.py.bak-p006c-*`)
     and confirm `brew list libolm` + `import mautrix, olm` in `venv` still resolve.
  2. Restart and run the four-point check in Drafting Table: **(a)** E2EE decrypts (Hermes reads a
     fresh encrypted message); **(b)** bare "hermes" → **silence**; **(c)** a full-MXID `@hermes`
     pill → **reply**; **(d)** bot-to-bot handoff — `@openclaw` full-MXID pill → Hermes responds.
- **Push as Hermes:** the clone's remote is `git@github-hermes:…`; the deploy key authenticates.
  After a Hermes push, refresh Claude's clone (`git -C ~/Developer/homelab pull --ff-only`) and the
  architect's (`ssh openclaw '… git pull --ff-only'`).
- Config: `~/.hermes/config.yaml` (model/provider/terminal.cwd/toolsets — Context Engine tool
  enabled). `~/.hermes/.env` (the old `CLAUDE_CODE_OAUTH_TOKEN` line is **disabled**; PKCE creds are
  pooled, not in `.env`).
