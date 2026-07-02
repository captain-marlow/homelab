#!/usr/bin/env bash
# Reset omega's session for the Drafting Table Matrix room via the gateway RPC.
# Run on the Mac (omega's gateway).
set -euo pipefail

# Non-interactive SSH strips PATH, so `openclaw` may not be found. Resolve the
# binary explicitly instead of trusting ambient PATH. (2026-07-02: a PATH miss
# produced `command not found`, which the old `|| echo` swallowed into a fake
# "Done" — the RPC never ran.)
OPENCLAW="${OPENCLAW:-$HOME/.npm-global/bin/openclaw}"
[[ -x "$OPENCLAW" ]] || { echo "FATAL: openclaw not executable at $OPENCLAW" >&2; exit 1; }

ROOM='!FKZTkwAIkROBtdHyCl:matrix.ryankennedy.dev'
key="agent:omega:matrix:channel:${ROOM}"
echo "--- resetting omega"
if ! out="$("$OPENCLAW" gateway call sessions.reset --params "$(printf '{"key":"%s"}' "$key")")"; then
  echo "  FATAL: RPC call failed for omega" >&2
  exit 1
fi
echo "$out" | grep -E '"ok"|"sessionId"|"totalTokens"' || true
# Gate success on observed evidence, not the pipeline's exit calm.
if grep -q '"ok": *true' <<<"$out" \
  && grep -qE '"totalTokens": *0[,} ]' <<<"$out" \
  && grep -qE '"sessionId": *"[^"]+"' <<<"$out"; then
  echo "  ✓ omega: ok + totalTokens:0 + sessionId present — verified"
else
  echo "  ✗ omega: reset NOT verified (see output above)" >&2
  exit 1
fi
echo "Done — omega shows ok + totalTokens:0 + a fresh sessionId. Reset confirmed."
