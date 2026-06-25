# Matrix Bot Channel — `@openclaw` on Synapse (P002)

Wiring the OpenClaw gateway into the self-hosted Matrix homeserver as the `@openclaw`
account: the single-bot proof for the architect↔main two-agent track, **with end-to-end
encryption working for the bot**.

- **Gateway:** OpenClaw on the `openclaw` LXC (CT, `192.168.1.175`), OpenClaw **2026.6.8**.
- **Homeserver:** `matrix.ryankennedy.dev` (Synapse CT171 — see `docs/proxmox/synapse-matrix.md`).
- **Bot account:** `@openclaw:matrix.ryankennedy.dev` (non-admin), device `openclaw-gateway`.
- **Status:** Live. Bot reads/responds over Matrix, gated to `@ryan`, **E2EE working**.

The Matrix channel is an **outbound client connection** — the gateway logs into Synapse as a
Matrix client and syncs. Nothing about the gateway is exposed to the network for this; the
gateway stays loopback-bound (`127.0.0.1:18789`).

---

## Configuration (`~/.openclaw/openclaw.json` on CT175)

The channel was configured by **editing `openclaw.json` directly** (not `openclaw channels add`)
— see the CLI-scope gotcha below. `channels.matrix`:

```json
{
  "enabled": true,
  "homeserver": "https://matrix.ryankennedy.dev",
  "userId": "@openclaw:matrix.ryankennedy.dev",
  "accessToken": { "source": "file", "provider": "matrix_openclaw_token_file", "id": "value" },
  "deviceName": "openclaw-gateway",
  "network": { "dangerouslyAllowPrivateNetwork": true },
  "dm": { "allowFrom": ["@ryan:matrix.ryankennedy.dev"], "sessionScope": "per-room" },
  "autoJoin": "allowlist",
  "autoJoinAllowlist": ["@ryan:matrix.ryankennedy.dev"],
  "encryption": true
}
```

Plus a secrets provider (mirrors the `google_websearch_key_file` pattern):

```json
"secrets": { "providers": {
  "matrix_openclaw_token_file": {
    "source": "file",
    "path": "~/.openclaw/secrets/matrix-openclaw-access-token.txt",
    "mode": "singleValue"
  }
}}
```

And the plugin entry: `plugins.entries.matrix = { "enabled": true }`.

### What each setting does
- **`accessToken`** — file-backed SecretRef, not plaintext (consistent with the Phase-6 SecretRef
  posture). Token obtained via the Matrix password-login API for `@openclaw`, device pinned to
  `openclaw-gateway`.
- **`network.dangerouslyAllowPrivateNetwork`** — required. On the LAN, split-horizon DNS resolves
  `matrix.ryankennedy.dev` to the NPM LAN IP (`192.168.1.110`), and OpenClaw's SSRF guard blocks
  private IPs by default. The label is generic; here it's well-scoped — this channel's only egress
  is the homeserver.
- **`dm.allowFrom`** — who the bot **responds** to. (Distinct from auto-join, below.)
- **`dm.sessionScope: per-room`** — **security-relevant.** Without it, all Matrix DM rooms share
  one conversation session, so context from an *encrypted* room can bleed into an *unencrypted*
  room's replies. `per-room` isolates each room.
- **`encryption: true`** — enables E2EE; on first start it auto-bootstraps `@openclaw`'s
  cross-signing + secret storage and self-verifies the bot device.
- **`autoJoin` / `autoJoinAllowlist`** — `autoJoin` is an enum (`"always" | "allowlist" | "off"`),
  and the allowlist it consults is **`autoJoinAllowlist`**, NOT `dm.allowFrom` (these are
  separate). See the auto-join gotcha.

---

## Secrets

| Secret | Location |
|--------|----------|
| `@openclaw` access token | `~/.openclaw/secrets/matrix-openclaw-access-token.txt` (600) on CT175; backup in `~/.homelab-secrets/` on the Mac |
| `@openclaw` / `@architect` passwords | `~/.homelab-secrets/matrix-bot-creds.txt` on the Mac |
| E2EE crypto store (cross-signing keys) | `~/.openclaw/matrix/accounts/default/…` on CT175 (persists across restarts) |
| E2EE recovery key | **not yet captured off-box** — follow-up (see below) |

---

## Gotchas (the hard-won part)

### The CLI is read-only by design → edit config directly, don't use `channels add`
The local CLI on CT175 is paired with `operator.read` only (deliberate hardening — the
`chmod 700 ~/.openclaw` + "CLI scope-upgrade warning consciously deferred" items from the build
plan). Any gateway-mediated write (`channels add`, `secrets.resolve`) triggers a **scope-upgrade
request** that the read-only device cannot self-approve; approval must come from a trusted operator
device (the **OpenClaw Control UI / webchat on the Mac**, not Telegram — Telegram lacks
`operator.approvals`). Rather than grant the box CLI standing admin (which would reverse the
hardening), the Matrix channel was configured by **editing `openclaw.json` directly + restarting**,
which needs no scope. The pending scope request is left for Ryan to resolve/reject later.

- Dashboard note: `openclaw dashboard` won't embed the token in the URL because `gateway.auth.token`
  is a SecretRef ("Token auto-auth is disabled for SecretRef-managed gateway.auth.token") — the
  Control UI prompts for it; supply the gateway token from `~/.openclaw/secrets/gateway-token.txt`.

### Plugin version floor
`@openclaw/matrix@latest` requires plugin API ≥ 2026.6.9, but the runtime is 2026.6.8. Installed the
**version-matched** plugin instead — `openclaw plugins install @openclaw/matrix@2026.6.8 --pin` —
so no runtime upgrade of the daily driver was needed.

### Validate before every restart
`autoJoin` must be the string enum, not a boolean — a `true` slipped through and the restart
aborted with an invalid config (the gateway kept running the prior good config; no outage). Always
`openclaw config validate` and only restart if it passes.

### E2EE specifics
- Enabling `encryption: true` **auto-bootstraps** cross-signing + secret storage on next start
  (log: `Cross-signing bootstrap complete` … `device is verified by its owner and ready for
  encrypted rooms`). No Element bootstrap needed for `@openclaw`.
- **Encrypted-invite auto-join is finicky** — it did not fire for encrypted DM invites even with
  `autoJoinAllowlist` set (auto-join keys off the live invite event and was unreliable here). The
  accepted path is **manual join** (one-time per room; see Operations). It's a small fixed set of
  rooms, so this is fine.
- A bot can only decrypt messages **sent after it joins** — Element shares Megolm keys with devices
  present at send time. After joining a room, send a *fresh* message to test.
- Decryption worked **without** Ryan verifying `@openclaw` (Element's default shares keys with
  unverified devices). User-verification (green shield / "only-verified-devices" robustness) is an
  optional follow-up.

---

## Operations

**Join the bot into a new room** (the one-time-per-room step, run from the Mac with the bot's token):
```bash
python3 - <<'PY'
import json, os, urllib.request, urllib.parse
HS="https://matrix.ryankennedy.dev"; rid="!ROOMID:matrix.ryankennedy.dev"
tok=open(os.path.expanduser("~/.homelab-secrets/matrix-openclaw-access-token.txt")).read().strip()
p=urllib.parse.quote(rid)
req=urllib.request.Request(HS+f"/_matrix/client/v3/rooms/{p}/join", data=b"{}", method="POST",
    headers={"Authorization":"Bearer "+tok,"Content-Type":"application/json"})
print(json.load(urllib.request.urlopen(req)))
PY
```

**Check what the bot is invited to / joined** — `GET /_matrix/client/v3/sync?timeout=0` with the
token; look at `rooms.invite` vs `rooms.join`.

**Restart after a config edit:** `openclaw config validate && openclaw gateway restart`.

**Channel logs:** `openclaw channels logs --channel matrix`.

**Config backups:** timestamped `openclaw.json.bak-*` alongside the live config (e.g.
`openclaw.json.bak-p002-matrix-*`), plus `.last-good`.

---

## Follow-ups (logged, non-blocking)

- **User-verify `@openclaw`** in Element (cross-user trust / green shield).
- **Back up the E2EE recovery key** off-box — the auto-bootstrap generated one that wasn't
  surfaced; the local crypto store is the working source of truth, but an off-box recovery key
  protects against store loss.
- **Resolve or reject the pending CLI scope-upgrade request** from a trusted operator surface.
- **Clean up** scratch test rooms created during the build.
- Investigate encrypted-invite auto-join (low priority — manual join accepted).
