# Homelab AI Agents — Step 1 Completion Record

**Date:** 2026-06-22
**Host:** `openclaw` LXC (Proxmox CT, Debian, static `192.168.1.175`)
**Scope:** Completion record for Step 1 of the build plan (Finish OpenClaw config, the daily driver). Companion to the build-plan, concepts-reference, and failover-reference documents. Records what changed, what was decided and why, what is deferred, and what is being watched. This record ensures the reasoning does not have to be re-derived later.

---

## 0. Status at a glance

Step 1 is **complete**. Every item is either done-and-verified, deliberately deferred with documentation, or applied-and-watching. The foundation (the actual daily driver) moved from "configured but unreconciled" to a verified, hardened, documented state. Nothing in the current state blocks Step 2 (Ollama LXC).

| Build-plan item | Outcome |
|---|---|
| 1–2. Reconcile memory + write routing/auth policy | Done. `MEMORY.md`/`OPEN-ISSUES.md` split; policy written with rationale. |
| 3. Fix embeddings | Deferred to Ollama tier — documented, silent-safe, root cause corrected. |
| 4. `chmod 700` + CLI scope warning | `chmod 700` applied; scope resolved via backend path (pairing declined). |
| 6. Context-pruning tuning | One evidence-backed change (`ttl 1h→20m`); ratios held as control. |
| 7. SecretRef migration | Done — 3 plaintext secrets → 1 accepted exception; residue scrubbed and verified. |
| (Emergent) Recovery-notification skill | Applied — closes a demonstrated policy-vs-behavior gap. |

Canonical file hashes at close:

- `MEMORY.md`: `37aa1ff1c0df1a9db8db1d47c03629c030c52861cd0a76c86ded944986d2d4bd`
- `OPEN-ISSUES.md`: `e87015e983b36e2914c3f41738639c08df44fd51059f793b3086b80dd8ddd809`
- `openclaw.json`: `653038473d8259924887e5f33a20f731d3f4a7e4346275621c9aa92818eb6421` (`config validate` passed)
- `.env`: `19e067f672adbbb375788cb10eb80af6374652186e14d4aebca18652d4c44261`

---

## 1. What changed

### Memory / planning split

- Durable policy lives in `~/.openclaw/workspace/MEMORY.md` (the boot file OpenClaw loads for normal sessions — confirmed live, not assumed).
- Transient open-issues / roadmap live in `~/.openclaw/workspace/OPEN-ISSUES.md`, with a one-line pointer from `MEMORY.md`.
- `MEMORY.md` now carries a consolidated **Routing & Auth Policy**: per-task routing rules, failover behavior (auto-switch on usage/rate limit, auto-recover, announce once per state change), and the auth design rationale (prefer subscription/OAuth primary; cross-provider fallbacks; durable static token on the intermittent Anthropic leg).
- The raw daily log `memory/2026-06-21.md` was left untouched (dedupe is a tracked follow-up, deliberately out of scope).

### Filesystem hardening

- `~/.openclaw` → `700 openclaw:openclaw` (confirmed sole owner is the gateway service user before applying; revert path recorded).
- `~/.openclaw/secrets` → `700`; secret files `gateway-token.txt` and `google-websearch-api-key.txt` → `600`.

### CLI scope-upgrade decision

- The normal CLI device remains at `operator.read`. Its scope-upgrade request bundled `operator.pairing` (device-approval authority) beyond the `operator.admin` actually needed.
- Admin gateway operations (`secrets.resolve` / `secrets.reload`) were run through the reserved direct-loopback backend path (`gateway-client` / `backend`, token-authenticated, `operator.admin`) instead of granting the bundle.
- The recurring doctor `scope upgrade pending approval` warning is **accepted**, not unresolved — there is a working admin route that does not require widening the device's authority.

### SecretRef migration

- **Google web-search key** migrated to a file-backed SecretRef:
  - config key `plugins.entries.google.config.webSearch.apiKey` → `SecretRef(file, provider=google_websearch_key_file)`
  - secret file `~/.openclaw/secrets/google-websearch-api-key.txt` (`600`)
- **Gateway token** relocated **same-value** (no rotation) to a file-backed SecretRef:
  - config key `gateway.auth.token` → `SecretRef(file, provider=gateway_token_file)`
  - `OPENCLAW_GATEWAY_TOKEN` **removed from `.env`** (env value won at startup, so both sources had to move together)
  - applied via local-shell edits + gateway restart, verified through a three-way gate (`systemctl is-active`, `openclaw health`, **live Telegram control-channel round-trip**) before proceeding
- **Anthropic default token** left as accepted plaintext in the agent auth store (`profiles.anthropic:default.token` in `openclaw-agent.sqlite`) — see §2.
- **Residue scrubbed and verified:** 11 obsolete backup/snapshot files removed; `~/.bash_history` lines containing the gateway-token and Google-key prefixes removed (and confirmed not resurrected after a shell cycle).
- **Two Phase 6 revert points retained and content-verified** (not just hash-checked):
  - `openclaw.json.bak-phase6-20260622T020945Z` (`c13b06…`) — confirmed pre-relocation: plaintext `gateway.auth.token`, no `gateway_token_file` provider.
  - `.env.bak-phase6-20260622T020945Z` (`4d60b5…`) — confirmed contains `OPENCLAW_GATEWAY_TOKEN`. (Hash matches an earlier snapshot because content was unchanged across those phases — valid, not mislabeled.)
- **`/tmp` blind spots closed by provenance** (sudo unavailable non-interactively): `/tmp/openclaw` and the systemd-logind `PrivateTmp` dir are both root-owned `0700`, unwritable by the `openclaw` gateway process — so they cannot contain a gateway-written secret. Not read; excluded by provenance, not assumption.

Audit at close: **1 plaintext finding** (the accepted Anthropic token), 0 unresolved refs, 0 shadowed refs, 2 legacy OAuth residues (out of static-SecretRef scope).

### Context pruning

- Single change applied: `agents.defaults.contextPruning.ttl` `1h → 20m`. Ratios (`softTrimRatio`, `hardClearRatio`) and `keepLastAssistants` deliberately held as control.
- Live without restart: the reload path is `kind: none`; the running gateway updated its in-process config snapshot and builds pruning settings from it at run setup, so the new TTL applies to new turns.

### Model-recovery notification skill (emergent)

- Drafted in response to an observed failure: OpenAI rate-limited → Sonnet fallback (confirmed live), but the promised switch-**back** notification never fired. The promise had no durable mechanism behind it.
- Applied as skill `model-recovery-notification` (status `ready`, scan clean). It creates one durable cron/commitment per cooldown event, runs a live status check before notifying, sends exactly one recovery notice (dedupe key = provider/model + reset timestamp; no spam on flapping), and requires verifying the job exists (`openclaw cron list` / `commitments`) before notification can be promised.
- `MEMORY.md` updated to record the mechanism as active durable behavior.

---

## 2. What was decided, and why

**Anthropic default token stays plaintext (accepted, not pending).** OpenClaw's SecretRef subsystem resolves config-key paths only, not auth-profile rows in the SQLite auth store. Forcing a ref into the profile would make the resolver send the literal ref-string to Anthropic as the token (i.e., the migration would actively break auth). The token is static (no refresh lifecycle), non-control, and now sits in a `700` dir unreadable by other service users. "Secrets not exposed" is the real goal; "audit shows zero" is the metric. Optimizing the metric here would break the thing. Revisit only if OpenClaw adds auth-profile SecretRef support.

**Gateway token relocated same-value, not rotated.** This is the control-channel token; rotating it mid-migration would introduce circular-auth risk (the backend verification path authenticates *with* this token). Same-value relocation proved the SecretRef path without ever changing the live credential, so there was no window where a wrong credential was in flight. Consequence recorded honestly: residue cleanup *reduced* exposure but did not make the token "truly clean." The retained backups and any freed disk blocks still hold the live value. True cleanup requires a future rotation (see §3).

**Backend path over the pairing grant.** `secrets.resolve`/`reload` need `operator.admin`, not `operator.pairing`. The CLI's bundled request included pairing (device-approval authority), which was broader than the task. Since the loopback backend path provides admin without widening the device, granting pairing would have been authority bought for no benefit. Least privilege held.

**Embeddings deferred to the Ollama tier.** Root cause corrected during diagnosis: embeddings default to OpenAI `text-embedding-3-small`, but the only OpenAI auth is Codex OAuth, which covers chat/completions and **not** embeddings (an entitlement gap, not a rolling quota; the earlier Gemini-collision theory was investigated and ruled out). Standing up a separate billed OpenAI embeddings key would provision a dependency that the local Ollama tier (Step 2) is designed to make redundant. So: defer, run on curated `MEMORY.md` + keyword/`rg` search, and host embeddings locally once Ollama is proven. A billed key is the fallback only if semantic memory is needed sooner.

**One-variable pruning tuning.** Workload data (recent percentiles; max observed `237k/272k` ≈ 87%) showed the real problem was `ttl: 1h` letting active multi-turn work climb toward the context ceiling, not the pressure ratios. There was no evidence the ratios were misfiring (the marker split was ~175 hard-clear vs 4 soft-trim, so soft-trim wasn't the active mechanism). Changing one knob keeps a live feedback loop legible: if peaks drop and cache-read holds, done; if not, ratios are the next lever, with evidence.

**Recovery-notification skill approved.** The live failure showed a real gap between stated policy ("announce once per state change") and behavior (the switch-back announcement didn't fire). The skill patches it structurally: the promise of notification is not allowed to exist until a durable, verified job backs it. The verification requirement is the key property. It makes the mechanism prove itself rather than be asserted.

---

## 3. Open items carried forward

**Blocking for Step 2:** none. The Ollama LXC work is cleanly independent of current foundation state.

**Non-blocking, tracked in `OPEN-ISSUES.md`:**

- Semantic memory unavailable until embeddings exist; preferred path is local Ollama embeddings after proof. `openclaw memory search` CLI can exit `0` with empty results after an embedding failure — empty is **not** proof of absence; use `memory_search` tool errors or direct `rg`/file reads as ground truth.
- **Gateway-token rotation** deferred (loopback-only, `700` dir, low exposure) but is the matched closing step to the same-value relocation: when it happens, also scrub/regenerate the two retained Phase 6 backups and consider session-log pruning. Until then, residue cleanup is "reduced exposure," not "eliminated."
- **Phase 5 `.env` work** (not done this session): re-home `TELEGRAM_BOT_TOKEN` (control-channel, do last/one-at-a-time); remove the `GOOGLE_WEBSEARCH_API_KEY` `.env` duplicate (config SecretRef already authoritative); `OPENAI_WHISPER_API_KEY` deferred until local Whisper. Run `openclaw secrets audit --check` after.
- Context **pruning ratios** still untuned (only TTL changed) — revisit only with post-change evidence.
- Daily log `memory/2026-06-21.md` has duplicate/stale blocks (dedupe later).
- Only `main` agent exists — recheck before assuming specialist agents.
- `.learnings/ERRORS.md` has a duplicate `ERR-20260622-002` heading (non-urgent; clean if the log becomes indexed).

**Roadmap (later steps):** provision + **prove** Ollama before routing traffic; manual routing before any semantic dispatcher; Hermes standalone → homelab-repo integration → OC↔Hermes bridge; Proxmox maintenance agent on Mac/Hermes (SSH-direct, read/propose-first); local Whisper via the Proxmox agent.

---

## 4. Watch list (pruning change)

- Pre-change high-water mark: `237k/272k` (~87%).
- Latest observed post-change: `189k/272k` (~69%), `100%` cached.
- Watch the next 2–3 large sessions for: **peak context below 237k**, **warm OpenAI cache-read holding ~97%+**, and no quality loss from cleared tool-output context.
- If peaks stay high → revisit ratios with evidence. If cache-read drops materially after 20–30 min pauses → `20m` TTL may be too short; consider `30m` (the inter-turn data showed active rhythm ~5 min p50, so 20m clears normal turns but can catch the occasional 21–22 min mid-work pause).
- Check method: `openclaw status` + parse recent session/trajectory records for max context and cache-read %; recount pruning markers (`[Old tool result content cleared]`, `[Tool result trimmed:]`).

---

## 5. Lessons logged (for the permanent record)

- **A promise needs a mechanism.** "I'll notify you when it switches back" failed because nothing durable was scheduled. Recovery promises now require a created-and-verified cron/commitment first.
- **Silent vs. loud failure.** Distinguish tools that fail loudly from those that exit `0` with misleading output. `openclaw memory search` is the latter — document the fallback (`rg`).
- **Provider-id quirk.** Google web search is invoked as provider id `gemini`, not `google` (`ERR-20260622-001`).
- **Shell history captures secrets.** Env-var assignments / command substitutions can leave full secrets in `~/.bash_history`. Scrub the file and account for live-shell rewrite on exit.
- **`rm`/`sed -i` are exposure reduction, not erasure.** Freed blocks persist until overwritten; with no rotation, a deleted copy is still a live credential. Adequate only because the live file holds the same value — `shred`-grade erasure only becomes meaningful after rotation.
- **Permission-denied is a hole in the proof, not evidence of absence.** Close it by reading with privilege, or by establishing provenance (root-owned dir the gateway can't write to) — never by assuming.
- **Don't chain commands for destructive/security phases.** Single-purpose commands with separate verification; the failures clustered on complex chained one-liners.
- **Verify the live process, not the intention/cached report.** Applied throughout: confirming the boot file, the running gateway's auth source, the control-channel round-trip after restart, and that the pruning TTL is actually live.

---

*Caveat carried from the build plan: tool versions, flags, and ecosystem details shift fast. Base actual commands on the bot's verified local syntax rather than guessed flags, and verify live process state over cached reports.*
