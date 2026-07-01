#!/usr/bin/env bash
# Reset architect + main (openclaw) sessions for the Drafting Table Matrix room
# via the gateway RPC (sessions.reset). Run on CT175. RPC rolls the session
# server-side — no self-bounce concern, safe any time.
set -euo pipefail
ROOM='!FKZTkwAIkROBtdHyCl:matrix.ryankennedy.dev'
for agent in architect main; do
  key="agent:${agent}:matrix:channel:${ROOM}"
  echo "--- resetting ${agent}"
  openclaw gateway call sessions.reset --params "$(printf '{"key":"%s"}' "$key")" \
    | grep -E '"ok"|"sessionId"|"totalTokens"' || echo "  (unexpected output — check above)"
done
echo "Done — a fresh sessionId per agent = reset confirmed."
