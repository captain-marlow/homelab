# Two-Agent Loop — architect ↔ main, mention-gated (P004)

The planning loop (Opus planner → human gate → executor) running inside the homelab, in a
self-hosted Matrix room. `@architect` plans (read-only Opus, P003); `@openclaw` executes
(the gateway, P002); `@ryan` gates. Both bots live in one room (**Drafting Table**), and
`allowBots: "mentions"` + `requireMention: true` make the room fully mention-gated — nothing
fires unless someone is explicitly `@`-mentioned.

- **Gateway:** OpenClaw on the `openclaw` LXC (CT175, `192.168.1.175`), OpenClaw **2026.6.8**.
- **Homeserver:** `matrix.ryankennedy.dev` (Synapse CT171 — see `docs/proxmox/synapse-matrix.md`).
- **Accounts:** `@openclaw` (account id `default`, executor, gpt-5.5) + `@architect`
  (account id `architect`, planner, Opus) — two Matrix identities on one gateway.
- **Loop room:** **Drafting Table** `!FKZTkwAIkROBtdHyCl:matrix.ryankennedy.dev` (encrypted;
  `@ryan` + both bots).
- **Status:** Live and verified. `@architect` plans when mentioned; `@openclaw` stays silent
  when unmentioned (the brake); both reachable end-to-end over Matrix.

This closes the deferred **gateway-path proof** from P003 (architect previously only exercised
via the embedded runner) — `@architect` now answers live through the gateway transport.

---

## Multi-account migration — additive, NOT a relocation

The P003 follow-up suggested *relocating* `@openclaw` into a `channels.matrix.accounts{}` map.
Reading the plugin code showed a **strictly safer** path, so we deviated:

- `@openclaw`'s E2EE crypto store is keyed by `accountKey` + `tokenHash` at
  `~/.openclaw/matrix/accounts/<accountKey>/<server>__<user>/<tokenHash>` (see
  `dist/storage-paths-*.js`). Its current store is under `accounts/default/`. **Changing its
  account id off `default`, or changing its token, would orphan the store → forced cross-signing
  re-bootstrap.**
- But `resolveConfiguredMatrixAccountIds` (`dist/account-selection-*.js`) returns the
  `accounts{}` map ids **plus** `DEFAULT_ACCOUNT_ID` ("default") whenever top-level config is
  present. So leaving `@openclaw` entirely at the top level (it stays the implicit `default`
  account, token untouched) **and only adding `accounts.architect`** connects *both* bots.

So the migration was **purely additive** — `@openclaw` never moved, its E2EE store kept its
original timestamp, zero disruption. The "multi-account shape" was achieved by adding the
architect account beside the implicit default, not by relocating the default.

Account configs **inherit** channel-level fields (`homeserver`, `network`, `encryption`,
`autoJoin`, …), with `dm`/`actions`/`execApprovals`/`botLoopProtection` deep-merged
(`resolveMergedAccountConfig`). So the architect account only needs its own identity bits.

### Config (`channels.matrix`, additions only)

```json
{
  "defaultAccount": "default",
  "contextVisibility": "all",
  "historyLimit": 30,
  "accounts": {
    "architect": {
      "userId": "@architect:matrix.ryankennedy.dev",
      "accessToken": { "source": "file", "provider": "matrix_architect_token_file", "id": "value" },
      "deviceName": "architect-gateway",
      "dm": { "allowFrom": ["@ryan:matrix.ryankennedy.dev"], "sessionScope": "per-room" }
    }
  },
  "rooms": {
    "!FKZTkwAIkROBtdHyCl:matrix.ryankennedy.dev": {
      "allowBots": "mentions",
      "requireMention": true
    }
  }
}
```

Plus the token's secrets provider (mirrors `matrix_openclaw_token_file`):

```json
"secrets": { "providers": {
  "matrix_architect_token_file": {
    "source": "file",
    "path": "~/.openclaw/secrets/matrix-architect-access-token.txt",
    "mode": "singleValue"
  }
}}
```

Plus the routing binding (top-level `bindings[]`, written by `openclaw agents bind --agent
architect --bind matrix:architect` — **no scope wall**, unlike `channels add`):

```json
"bindings": [ { "type": "route", "agentId": "architect", "match": { "channel": "matrix", "accountId": "architect" } } ]
```

Without the binding, messages on the `architect` account would route to the default agent
(`main`/gpt-5.5) instead of the architect agent (Opus).

---

## The mention-gate (the human-gated brake)

The loop room is configured at **channel level** under `rooms` with **no `account` field**, so
the entry applies to **both** accounts (`selectInheritedMatrixRoomEntries` includes entries with
no account; an `account:` field would scope it to one identity).

- **`allowBots: "mentions"`** — a configured bot's message triggers the *other* bot only when it
  `@`-mentions that bot **with the full MXID** (see "Bots CAN trigger each other" below). Default is
  `false` (bots ignore each other entirely).
- **`requireMention: true`** — humans must `@`-mention a bot to trigger it too. Together: the
  whole room is mention-gated; nothing fires unprompted.
- **`botLoopProtection`** — auto-enabled whenever `allowBots` is `true`/`"mentions"` (defaults:
  20 accepted bot-pair msgs / 60 s window, then 60 s cooldown). The runaway backstop behind the
  mention gate.
- **`groupPolicy` defaults to `"open"`** (and `allowlistOnly` is unset), so the bots respond in
  the room without a group allowlist — the room being private (invite-only, `@ryan` + 2 bots) is
  the boundary.

### Context visibility — required for bots to read each other

For a bot to *read* another bot's message, it must be allowed to see it. **`contextVisibility`
defaults to an allowlist of (human) senders, so a bot's messages are filtered out of another bot's
context** — symptom: `@openclaw`, mentioned by `@ryan` to "read the architect's response," replied
it couldn't see it. Fix: set channel-level **`contextVisibility: "all"`** (enum: `all` |
`allowlist` | `allowlist_quote`) so all room messages are visible, plus **`historyLimit: 30`** for a
recent window. Both are channel-level (the per-room `rooms{}` schema has neither). Safe here because
the bots are only ever in private, controlled rooms.

> E2EE caveat: a bot can only read messages it holds Megolm keys for (sent while it was in the
> room). `contextVisibility: "all"` surfaces decryptable history; it can't recover pre-join content.

### Bots CAN trigger each other — but only via the full MXID

**A bot's @mention fires the other bot only if it uses the full MXID**
(`@openclaw:matrix.ryankennedy.dev`), which OpenClaw's outbound path converts to a real
`m.mentions` pill → the target gets `was_mentioned: true` and activates (gated by
`allowBots: "mentions"`). A **bare localpart** (`@openclaw`) stays inert text and triggers nothing.
Humans get the pill for free (Element autocomplete); bots must emit the full MXID in the body.

**Verified live (in the loop itself):** `@architect` and `@openclaw` each activated the other using
full MXIDs (`was_mentioned: true` on receipt); bare-localpart attempts landed as flat text and did
nothing. So **autonomous planner↔executor handoff works** — the human is not strictly required to
relay, and a two-way loop between the agents is possible. (`contextVisibility:"all"` is what lets
the triggered bot also *read* the other's message, not just be pinged.)

**Brakes — the human stays in control by convention + backstop, not a hard wall:**
- **Kill-switch:** deliberately **omit the mention** — a final line with no full-MXID mention ends
  the chain. (Demonstrated live: step-3 "no mention" terminated a test loop.)
- **`botLoopProtection`** — 20 accepted bot-pair msgs / 60 s, then 60 s cooldown (runaway backstop).
- **`requireMention: true`** — nothing fires without a mention at all.
- **Agent SOUL discipline** — architect/openclaw can be instructed in their identity not to mention
  each other unless told, keeping `@ryan` the initiator. This is the *soft* gate. For a *hard* gate,
  withhold the other bot's full MXID from context or tighten policy.

> **Correction:** an earlier version of this doc claimed bots *couldn't* trigger each other. That
> was a **format misdiagnosis** — bare localpart (inert) vs full MXID (real pill) — overturned by
> live testing. `mentionPatterns` (regex) could make bare "@name" count too, but it's unnecessary
> since full MXIDs already work.

---

## Token minting — via localhost, not the public URL

**Finding (hard-won):** Synapse `POST /_matrix/client/v3/login` (`m.login.password`) returns
**403 M_FORBIDDEN via the public URL** (`https://matrix.ryankennedy.dev` → NPM/CT110) for the
bot accounts, but the **same login succeeds against `http://localhost:8008` on CT171**.
Token-authenticated requests (sync, whoami, send) work fine via the public URL — only
unauthenticated password-login is rejected on that path. Root cause not yet diagnosed
(Element login works for `@ryan`); logged as a follow-up.

So `~/homelab-secrets/matrix-bot-creds.txt` is **accurate, not stale**. Minting procedure:

1. Log in as `@architect` against `localhost:8008` **on CT171** (device `architect-gateway`),
   password fed via stdin (never argv/chat).
2. Transfer the token to CT175 (`scp -3` to `~/.openclaw/secrets/matrix-architect-access-token.txt`,
   600, owned by `openclaw`). The token is server-wide — works via the public URL afterward
   (verified with `/account/whoami` through the gateway path).

> **Detour, recorded honestly:** the public-URL 403 was first misread as a *stale creds file*,
> and `@architect`'s password was reset server-side (hash via Synapse's `hash_password`, single-row
> DB update) — then **reverted from a hash backup** once `localhost` proved the file was fine. Net
> effect on Synapse: one intended new device (`architect-gateway`); password unchanged. The
> throwaway test devices from the diagnosis were revoked. Lesson: **test against `localhost:8008`
> before suspecting a Matrix password.**

---

## Manual room-join (per P002)

Encrypted-invite auto-join is unreliable, so bots are **manually joined** per room via the join
API with each bot's token (one-time per room). Watch for:

- **Joins via the DB, not ad-hoc `/sync`.** A parallel `/sync?timeout=0` query (separate from the
  gateway's live sync) misreported membership (showed `invite` when room state said `join`). Ground
  truth: `select user_id, membership from local_current_membership where room_id=…` on CT171.
- **DM vs room.** A Matrix DM is a 2-person room; the loop needs a **group room** (`@ryan` + both
  bots). A room you *create then leave* goes dead ("Can't join remote room because no servers that
  are in the room have been provided" — no joined members left), and bots can't join it.
- **Fresh messages after join.** A bot only decrypts messages sent *after* it joins (Megolm keys
  shared at send time). Test with a new message.

---

## Operations

- **Join a bot into a new room:** `POST /_matrix/client/v3/rooms/{roomId}/join` with the bot's
  token (from `~/.openclaw/secrets/`). Confirm via CT171 `local_current_membership`.
- **Mint/replace a bot token:** login against `localhost:8008` on CT171, then `scp -3` to the
  CT175 secrets file (600). Restart the gateway.
- **Start a fresh bot session (clear context):** send **`/reset`** (single slash) with the target
  bot mentioned. **Confirmed live:** Element passes it through; the *runtime* consumes it as a
  command (the model never runs — no "typing"), archives the old transcript, and starts a fresh
  session. Caveats:
    - **No visible acknowledgment** — the reset is silent (a bug; the "✅ Session reset" ack isn't
      delivered). openclaw confirmed via runtime/logs that the reset *did* happen.
    - **`//reset` (double slash) is NOT a command** — it reaches the model as literal text and does
      nothing. Use the single slash.
    - **Per-bot** in a group room — mention the specific bot to reset only its session.
    - **The architect can't self-confirm a reset** — the reset wipes the context that would prove
      it (it may even deny it reset). Verify via **openclaw / logs**, never by asking the architect.
    - `/new` likely also works (untested); `/reset` is the confirmed one.
- **Add another gated room:** add a `channels.matrix.rooms["!id:…"]` entry (`allowBots:"mentions"`,
  `requireMention:true`), `openclaw config validate`, `openclaw gateway restart`.
- **Restart after config edits:** `openclaw config validate && openclaw gateway restart`
  (interrupts `main`'s in-flight turn). Config backups: `openclaw.json.bak-p004-*` on CT175.
- **Refresh the architect's knowledge:** `git -C ~/.openclaw/agents/architect/workspace/homelab
  pull` (origin must stay current — the architect plans from the pushed repo).

---

## Follow-ups (logged, non-blocking)

- **Public-URL password-login 403** — diagnose the NPM/Synapse path (Element works for `@ryan`;
  bot password-login via the public URL doesn't). Low urgency — token auth works.
- **`/reset` delivers no visible acknowledgment** — the session reset happens but the expected
  "✅ Session reset" confirmation isn't sent (openclaw-confirmed). Cosmetic/UX bug; reset works.
- **User-verify the bots** in Element (green shield) — carried over from P002.
- **Back up the E2EE recovery keys** off-box (both accounts) — carried over from P002.
- **Resolve/reject the pending CLI scope-upgrade request** — carried over from P002.
- **Architect repo refresh is manual** (`git pull`) — tighten to cron/webhook only if it proves
  annoying.
