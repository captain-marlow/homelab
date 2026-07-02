#!/usr/bin/env bash
# Reset omega's session for the Drafting Table Matrix room via the gateway RPC.
# Run on the Mac (omega's gateway).
set -euo pipefail

# Resolve openclaw robustly rather than trusting one hardcoded path. Order:
# explicit override → PATH → mise (survives node bumps) → legacy npm-global (CT175).
# On the Mac, openclaw lives under a mise-managed, version-pinned node dir, which
# rots on every node bump — a bare npm-global default is wrong here.
resolve_openclaw() {
  [[ -n "${OPENCLAW:-}" ]] && { printf '%s' "$OPENCLAW"; return; }
  local c
  c="$(command -v openclaw 2>/dev/null)" && [[ -n "$c" ]] && { printf '%s' "$c"; return; }
  if command -v mise >/dev/null 2>&1; then
    c="$(mise which openclaw 2>/dev/null)" && [[ -n "$c" ]] && { printf '%s' "$c"; return; }
  fi
  printf '%s' "$HOME/.npm-global/bin/openclaw"
}
OPENCLAW="$(resolve_openclaw)"
[[ -x "$OPENCLAW" ]] || { echo "FATAL: openclaw not executable at '$OPENCLAW'" >&2; exit 1; }

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
