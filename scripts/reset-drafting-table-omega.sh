#!/usr/bin/env bash
# Reset omega's session for the Drafting Table Matrix room via the gateway RPC.
# Run on the Mac (omega's gateway).
set -euo pipefail
ROOM='!FKZTkwAIkROBtdHyCl:matrix.ryankennedy.dev'
key="agent:omega:matrix:channel:${ROOM}"
echo "--- resetting omega"
openclaw gateway call sessions.reset --params "$(printf '{"key":"%s"}' "$key")" \
  | grep -E '"ok"|"sessionId"|"totalTokens"' || echo "  (unexpected output — check above)"
echo "Done — a fresh sessionId = reset confirmed."
