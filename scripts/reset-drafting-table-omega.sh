#!/usr/bin/env bash
# reset-drafting-table-omega.sh
#
# Resets the omega agent session for the "Drafting Table" Matrix channel
# (room !FKZTkwAIkROBtdHyCl:matrix.ryankennedy.dev), giving omega a clean
# slate on next message. Runs on the Mac (where omega lives at ~/.openclaw).
# For main and architect (CT175-side), use scripts/reset-drafting-table.sh.
#
# HOW IT WORKS
#   OpenClaw stores session history in per-agent .jsonl transcript files.
#   Renaming <sessionId>.jsonl -> <sessionId>.jsonl.reset.<timestamp> is the
#   same pattern the gateway itself uses for resets. The gateway detects the
#   missing transcript on the next incoming message and starts a fresh session.
#   No restart is needed; the gateway must be running.
#
# SELF-BOUNCE WARNING
#   DO NOT run this from inside the omega session (e.g. via tool calls). Run
#   it directly from a Mac shell, BEFORE sending the next message to omega.
#   Running it while an omega turn is in-flight may corrupt state.
#
# SESSION KEY RESET
#   omega agent: agent:omega:matrix:channel:!FKZTkwAIkROBtdHyCl:matrix.ryankennedy.dev
#
# USAGE
#   bash scripts/reset-drafting-table-omega.sh [--dry-run]
#
# REQUIREMENTS
#   Run on the Mac where omega's gateway lives (~/.openclaw).
#   jq must be installed; python3 is a fallback if jq is absent.

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[dry-run] No files will be modified."
fi

AGENTS_BASE="${HOME}/.openclaw/agents"
TIMESTAMP="$(date -u +%Y-%m-%dT%H-%M-%S)Z"

AGENT="omega"
SESSION_KEY="agent:omega:matrix:channel:!FKZTkwAIkROBtdHyCl:matrix.ryankennedy.dev"

sessions_dir="${AGENTS_BASE}/${AGENT}/sessions"
sessions_json="${sessions_dir}/sessions.json"

echo "--- [${AGENT}] ---"

if [[ ! -f "$sessions_json" ]]; then
  echo "  sessions.json not found at ${sessions_json} — skipping"
  exit 0
fi

# sessions.json is a flat dict: { "<session_key>": { sessionId, sessionFile, ... }, ... }
if command -v jq &>/dev/null; then
  session_file=$(jq -r --arg key "$SESSION_KEY" '.[$key].sessionFile // empty' "$sessions_json" 2>/dev/null || true)
  session_id=$(jq -r --arg key "$SESSION_KEY" '.[$key].sessionId // empty' "$sessions_json" 2>/dev/null || true)
else
  read -r session_id session_file < <(python3 -c "
import json, sys
data = json.load(open('${sessions_json}'))
entry = data.get('${SESSION_KEY}', {})
print(entry.get('sessionId', ''), entry.get('sessionFile', ''))
" 2>/dev/null || echo "")
fi

if [[ -z "$session_id" ]]; then
  echo "  Session key not found in store: ${SESSION_KEY}"
  exit 0
fi

echo "  Session ID: ${session_id}"

# Prefer the sessionFile path from the store; fall back to constructed path
src="${session_file:-${sessions_dir}/${session_id}.jsonl}"
dst="${src}.reset.${TIMESTAMP}"

if [[ ! -f "$src" ]]; then
  echo "  Transcript file not found (may already be reset): ${src}"
  exit 0
fi

if $DRY_RUN; then
  echo "  [dry-run] Would rename: ${src}"
  echo "         -> ${dst}"
else
  mv "$src" "$dst"
  echo "  Reset: ${src}"
  echo "     -> ${dst}"
fi

echo ""
if $DRY_RUN; then
  echo "Dry run complete. Re-run without --dry-run to apply."
else
  echo "Done. Omega session will start fresh on next message."
fi
