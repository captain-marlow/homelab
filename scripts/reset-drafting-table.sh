#!/usr/bin/env bash
# Reset architect + main (openclaw) sessions for the Drafting Table Matrix room
# via the gateway RPC (sessions.reset). Run on CT175. RPC rolls the session
# server-side — no self-bounce concern, safe any time.
set -euo pipefail

# Non-interactive SSH strips PATH, so `openclaw` may not be found. Resolve the
# binary explicitly instead of trusting ambient PATH. (2026-07-02: a PATH miss
# produced `command not found`, which the old `|| echo` swallowed into a fake
# "Done" — the RPC never ran.)
OPENCLAW="${OPENCLAW:-$HOME/.npm-global/bin/openclaw}"
[[ -x "$OPENCLAW" ]] || { echo "FATAL: openclaw not executable at $OPENCLAW" >&2; exit 1; }

ROOM='!FKZTkwAIkROBtdHyCl:matrix.ryankennedy.dev'
fail=0
for agent in architect main; do
  key="agent:${agent}:matrix:channel:${ROOM}"
  echo "--- resetting ${agent}"
  if ! out="$("$OPENCLAW" gateway call sessions.reset --params "$(printf '{"key":"%s"}' "$key")")"; then
    echo "  FATAL: RPC call failed for ${agent}" >&2
    exit 1
  fi
  echo "$out" | grep -E '"ok"|"sessionId"|"totalTokens"' || true
  # Gate success on observed evidence, not the pipeline's exit calm.
  if grep -q '"ok": *true' <<<"$out" \
    && grep -qE '"totalTokens": *0[,} ]' <<<"$out" \
    && grep -qE '"sessionId": *"[^"]+"' <<<"$out"; then
    echo "  ✓ ${agent}: ok + totalTokens:0 + sessionId present — verified"
  else
    echo "  ✗ ${agent}: reset NOT verified (see output above)" >&2
    fail=1
  fi
done
if [[ $fail -ne 0 ]]; then
  echo "One or more resets failed to verify — NOT confirmed." >&2
  exit 1
fi
echo "Done — every agent shows ok + totalTokens:0 + a fresh sessionId. Reset confirmed."
