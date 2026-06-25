# OpenClaw Failover & Auth Hardening — Reference Log

**Date:** 2026-06-21
**Host:** `openclaw` LXC (Proxmox CT, Debian, static `192.168.1.175`)
**Gateway version:** OpenClaw 2026.6.8 (844f405)
**Scope of this document:** Full record of the model-failover, image-gen, prompt-caching, and Anthropic/Google auth-hardening work completed in this session. This covers *what* was changed, *where* it lives, and *why* each decision was made, so the reasoning doesn't have to be re-derived later.

---

## 1. Goal & Outcome

**Starting problem:** When the OpenAI/Codex subscription hit its rolling usage limit, OpenClaw errored instead of switching models. Recovery required manually running `openclaw models set <model>` and restarting the gateway every time.

**End state:** A three-deep, cross-provider text failover chain that switches automatically on a rate limit and announces the transition, with each leg's auth hardened for durability. The chain was **stress-tested by a real triple-failure during the session** (see §6) and behaved correctly. The original manual-switching problem is resolved and proven live.

---

## 2. Final Proven Configuration

### Text model chain

| Role | Model | Auth method | Durability |
|------|-------|-------------|------------|
| Primary | `openai/gpt-5.5` | OpenAI Codex OAuth (`openai:ryan+openai@ryankennedy.me`) | Subscription; 5h rolling usage cap is what triggers failover |
| Fallback 1 | `anthropic/claude-sonnet-4-6` | Anthropic setup-token (`anthropic:default`, static) | **Durable — no short expiry** |
| Fallback 2 | `google/gemini-3-flash-preview` | Google API key, file-backed SecretRef (`google:manual`) | Free-tier, durable key |

### Image chain

| Role | Model | Notes |
|------|-------|-------|
| Primary | `openai/gpt-image-2` | OpenAI; rides Codex OAuth |
| Fallback | *(none)* | Intentionally empty — see §5 |

### Config keys of record

- `agents.defaults.model.primary` = `openai/gpt-5.5`
- `agents.defaults.model.fallbacks` = `[anthropic/claude-sonnet-4-6, google/gemini-3-flash-preview]`
- `agents.defaults.imageModel.primary` = `openai/gpt-image-2`
- `agents.defaults.imageModel.fallbacks` = `[]`
- `agents.defaults.params.cacheRetention` = `"long"`
- Provider catalog (`models.providers.google`) registered for `gemini-3-flash-preview` (see §4)

> Note: the effective provider catalog lives in `~/.openclaw/openclaw.json`. `~/.openclaw/agents/main/agent/models.json` currently has `providers: {}`.

---

## 3. Why the chain is ordered this way (rationale)

- **First fallback is a *different provider* (Anthropic), not another OpenAI model.** When OpenAI rate-limits, *all* its models are limited simultaneously — falling back within the same provider would hit the same wall. Cross-provider is the only useful failover. Gemini is fallback 2 for the same reason (third distinct provider).
- **"Usage limit" errors are treated as failover-worthy** by OpenClaw, and it auto-recovers to the primary when the limit resets, announcing the transition once per state change. This is the behavior that replaced manual switching.
- **No API-key primary.** Goal was to stay on subscription/OAuth where possible. Codex (OAuth) primary, Anthropic setup-token fallback, Google free-tier key fallback — no pay-per-token *primary* path.

---

## 4. Google / Gemini setup (the longest thread)

### Key facts established

- **A Gemini *subscription* and a Gemini *API key* are different products.** The subscription (Gemini app) does **not** grant API access. API keys come from **Google AI Studio** (`aistudio.google.com`), free tier, no credit card required.
- **Google removed all *Pro* models from the free tier on 2026-04-01.** `gemini-3.1-pro-preview` returns `limit: 0` on a free-tier key — structurally paid-only, not a transient rate limit. Pricing page lists it as "Free Tier: Not available."
- **Free tier covers only Flash / Flash-Lite.** `gemini-3-flash-preview` has real free quota (~1,500 RPD, 10 RPM, 1M context, supports function calling) — which is why it's the chosen fallback.
- **The Gemini-CLI OAuth path is an *unofficial* integration** with documented account-restriction risk. The API-key path is the officially supported one and was used instead.
- **Two separate Google keys are in play, by design:**
  - `GOOGLE_WEBSEARCH_API_KEY` (prefix `AQ.Ab…`) — web search via Gemini grounding. Untouched.
  - Gemini *model* key — now stored as a file-backed SecretRef (below).

### What was built

1. **Provider catalog registration** — `models.providers.google` added to `openclaw.json`:
   - `api: google-generative-ai`
   - `baseUrl: https://generativelanguage.googleapis.com/v1beta`
   - model `gemini-3-flash-preview`, `input: [text, image]`, `reasoning: true`, `contextWindow: 1048576`, `maxTokens: 65536`, zero-cost fields.
   - *Required because* the model was in the fallback list but unresolvable ("Unknown model") without a catalog entry.
2. **File-backed SecretRef for the key** (chosen over env-backed deliberately — see rationale):
   - Secret file: `~/.openclaw/secrets/gemini-api-key.txt`, mode `0600`
   - `secrets.providers.gemini_key_file = { source: "file", path: "~/.openclaw/secrets/gemini-api-key.txt", mode: "singleValue" }`
   - Auth profile in agent SQLite: `google:manual [google/api_key]`, resolving as `ref(file:value)`
   - **Why file-backed, not env-backed:** an env-backed ref would depend on `.env`, which was being renamed in the same session. File-backed made Gemini auth independent of the env file *before* touching it.
3. **Removed the plaintext `GEMINI_API_KEY` from the env file** after the SecretRef was proven, so the SecretRef is the single source (confirmed: `models status` no longer shows an `env=` line for Google).

### `cacheRetention: "long"` and Gemini

Setting `cacheRetention: "long"` enables OpenClaw's managed `cachedContents` for direct Gemini runs (1h TTL). Measured at ~88% cache reads on repeat Flash turns after the change.

---

## 5. Image fallback: why it's empty (not an oversight)

`gemini-3.1-flash-image-preview` was added as an image fallback, then **removed** after a direct API probe returned:

```
429 RESOURCE_EXHAUSTED
generate_content_free_tier_requests, limit: 0, model: gemini-3.1-flash-image
generate_content_free_tier_input_token_count, limit: 0
```

Same structural free-tier wall as Gemini Pro text. **Zero quota, billing-gated**, not transient. Decision: **drop it rather than keep a configured-but-dead fallback**, because a fallback that can never complete creates false confidence (you'd believe you had image redundancy when you didn't). Image-gen is rare and the OpenAI primary works, so `gpt-image-2` with *no* fallback is the honest state. Revisit only if image redundancy is genuinely needed (would require enabling Google billing).

---

## 6. The triple-failure event (live stress test)

Mid-session, a real simultaneous three-leg failure occurred and was captured in logs:

```
All models failed (3):
  openai/gpt-5.5: in cooldown (rate_limit)              — Codex 5h window exhausted (~50m to reset)
  anthropic/claude-sonnet-4-6: login expired (auth)     — Claude CLI OAuth expired, no credentials
  google/gemini-3-flash-preview: 503 high demand        — transient Google overload
```

**What it proved:**

- The failover logic **worked correctly** — it tried all three legs in order and reported precisely why each failed (no pinning, no hang).
- The error was an *honest* result of all three being genuinely down, not a failover bug.
- **The root cause was the middle leg already being dead** (Sonnet's OAuth expired). Had Sonnet been healthy, Codex's cooldown would have rolled to it silently with no user-visible error.

This exposed the one real weakness (Claude OAuth fragility, §7) and led directly to the durability fix.

---

## 7. Anthropic auth hardening (the durability fix)

### The problem

The Claude leg was running on **Claude CLI OAuth** (`anthropic:claude-cli`). Findings:

- **OpenClaw does not auto-refresh the Claude CLI OAuth token.** It reads the `claude` binary's stored session at use-time; if `claude` hasn't independently refreshed, OpenClaw's view goes stale/expired. There is **no OpenClaw-owned refresh loop** for this path.
- This makes it **structurally fragile for a long-lived gateway** — it expires on any session that outlives the access token (~8h) unless `claude` is independently invoked.
- A `claude -p "ping"` test earlier showed it *working at that moment* — but that proved the token was *valid then*, not that it *refreshes on expiry*. It later expired during the session.

### The fix

1. **Created an Anthropic setup-token** via `openclaw models auth login --provider anthropic → Anthropic setup-token`.
   - Stored as profile `anthropic:default [anthropic/token]` (`sk-ant-o…`), **static — no short expiry**.
   - Note: OpenClaw confirms this path is sanctioned ("Anthropic staff told us this OpenClaw path is allowed again").
   - **Headless auth note:** the `claude setup-token` flow is *paste-back*, not local-redirect — open the URL, authorize, copy the auth code back into **Claude Code** (not OpenClaw's prompt), which then emits the `sk-ant-oat01-…` token. No SSH port-forward/tunnel needed. The code is single-use and time-limited (short window — re-run if it times out).
2. **Set auth-order override so the durable token leads:**

   ```
   openclaw models auth order set --provider anthropic anthropic:default
   ```

   - Proven via `--probe`: `anthropic:default (token) = ok`; `anthropic:claude-cli (oauth) = Excluded by auth.order`.
   - The OAuth profile **remains present as a deprioritized secondary** (recoverable, and pin-able per-session via `/model claude-sonnet-4-6@anthropic:claude-cli`).

### Why durable-token-first, not OAuth-first

The intuition "it's just a fallback, OAuth is fine" is **backwards**. The OAuth failure mode is *expiry from disuse*, and a fallback leg is *idle by definition* (it only fires when the primary is down, possibly days apart). So the leg touched least is exactly where a decay-from-disuse credential is most dangerous. The static token doesn't decay, so it belongs on the intermittent leg. Also: OpenClaw did **not** demonstrably fall through from a failed Anthropic profile to a second one (the triple-failure showed a hard auth error, not a profile rotation), so whatever profile is *first* must work, which is the durable token.

---

## 8. Environment file normalization

- **Renamed** `~/.openclaw/openclaw.env` → `~/.openclaw/.env` to match OpenClaw's documented global dotenv path (the host had a non-standard service-specific filename, which was the likely cause of the shell-vs-gateway env visibility split).
- **Updated** the systemd user unit: `EnvironmentFile=%h/.openclaw/.env` in `~/.config/systemd/user/openclaw-gateway.service`.
- **Sequencing:** done *after* the Gemini SecretRef was in place, so the gateway no longer depended on the env file for Gemini auth before the rename touched it.
- **Current `.env` keys:** `GOOGLE_WEBSEARCH_API_KEY`, `OPENAI_WHISPER_API_KEY`, `OPENCLAW_GATEWAY_TOKEN`, `PATH`, `TELEGRAM_BOT_TOKEN`. (`GEMINI_API_KEY` removed.)

---

## 9. Prompt caching (Task 3 Part A) — measured

- `cacheRetention: "long"` set globally (`agents.defaults.params`).
- **OpenAI:** essentially flat before/after (~74.5% avg, already ~90%+ on warm turns) — it was already caching automatically; the retention knob added little because there was no headroom. Flat is *expected*, not a failure. (`cacheWrite` stays 0 on OpenAI by design.)
- **Gemini Flash:** ~88% cache reads on repeat turns after the change (no valid "before" — Pro was blocked at the time of baseline).
- **Conclusion:** caching works; the practical win is modest because OpenAI (the bulk of traffic) was already maxed. Real token headroom is in **Part B (history/context pruning)**, deferred.

---

## 10. Operational notes & gotchas (for next time)

- **`systemctl --user` works cleanly via direct SSH login as the `openclaw` user.** The `XDG_RUNTIME_DIR` / "Transport endpoint is not connected" errors only appear in `su` sessions. An SSH key was copied into `openclaw`'s `authorized_keys` (from root's) to enable direct login — this eliminated the recurring restart headache.
- **The SSH shell is the source of truth, not the Telegram "typing" indicator.** A gateway restart kills the in-flight turn, so the bot may complete work without reporting it. Verify state with `openclaw models status` / `openclaw logs --follow`.
- **Verification pattern used throughout:** `openclaw infer model run --gateway --model <provider/model> --prompt 'ping' --json`. The `--gateway` flag forces the call through the *running gateway* (the real failover path) rather than embedded execution. `"transport": "gateway"` in the output confirms it. **Auth-present ≠ works; works-embedded ≠ works-through-gateway.**
- **Timestamped backups are the durable rollback points.** The bare `~/.openclaw/openclaw.json.bak` (no timestamp) gets overwritten by the next generic-backup command; reach for the timestamped files.

---

## 11. Backups created today

```
~/.openclaw/openclaw.json.bak.1 … .bak.4 (+ bare .bak)
~/.openclaw/openclaw.env.bak.20260621_042013
~/.openclaw/agents/main/agent/auth-store.bak.20260621_041830
~/.openclaw/agents/main/agent/openclaw-agent.sqlite.bak-20260621T063038Z
```

## 12. Files written / changed today

```
~/.openclaw/openclaw.json
~/.openclaw/.env                         (renamed from openclaw.env)
~/.openclaw/secrets/gemini-api-key.txt   (new, 0600)
~/.config/systemd/user/openclaw-gateway.service
~/.openclaw/agents/main/agent/openclaw-agent.sqlite
~/.openclaw/workspace/memory/2026-06-21.md
~/.openclaw/workspace/MEMORY.md          (setup summary added)
```

---

## 13. Known issues / open items

### Surfaced this session (worth noting)

- **Embedding/semantic-memory quota exhausted** — semantic memory search was unavailable due to embedding quota exhaustion. Likely the Gemini/Google free-tier quota for embeddings. Worth investigating which key/project backs embeddings and whether it needs isolation.
- **Two memory artifacts exist** — `MEMORY.md` (snapshot) and `memory/2026-06-21.md` (dated log). Reconcile so the canonical state lives wherever OpenClaw actually reads at boot.
- **`secrets audit` is not clean** — still flags plaintext `gateway.auth.token`, the Google web-search key, the `anthropic:default.token`, and OAuth residues for OpenAI / Claude CLI.

### Deferred backlog (next sessions)

1. **Local Ollama tier** — a 4th, *unkillable* fallback under Gemini (can't expire/revoke/rate-limit/503). The structural answer to the §6 triple-failure. *(64GB host can run a strong quantized model.)*
2. **Full SecretRef migration** — migrate remaining plaintext secrets (Telegram token, gateway token, Whisper key, web-search key) to file-backed SecretRefs → `openclaw secrets audit --check clean`. Careful: some are load-bearing for the control channel. The Gemini key is the template/first instance.
3. **Task 3 Part B — history/context pruning** (`contextPruning.mode: "cache-ttl"` + reviewed trim threshold). Where the real token savings are, since OpenAI is already cache-maxed.
4. **Local Whisper** — replace the paid `OPENAI_WHISPER_API_KEY` (`sk-sv…`) transcription dependency with a local model.
5. **MEMORY.md routing policy** — record routing/auth policy as durable bot instructions now that the chain is settled.
6. **Watch:** confirm the deprioritized `claude-cli` OAuth exclusion holds; Anthropic subscription has its own rolling usage cap that heavy Codex→Sonnet failover draws on.
