#!/usr/bin/env bash
# reset-drafting-table.sh
#
# Resets both agent sessions for the "Drafting Table" Matrix channel
# (room !FKZTkwAIkROBtdHyCl:matrix.ryankennedy.dev), giving both openclaw
# and architect a clean slate on next message.
#
# HOW IT WORKS
#   OpenClaw stores session history in per-agent .jsonl transcript files.
#   Renaming <sessionId>.jsonl -> <sessionId>.jsonl.reset.<timestamp> is the
#   same pattern the gateway itself uses for resets. The gateway detects the
#   missing transcript on the next incoming message and starts a fresh session.
#   No restart is needed; the gateway must be running.
#
# SELF-BOUNCE WARNING
#   DO NOT run this from inside the openclaw or architect sessions (e.g. via
#   tool calls). Run it directly from a shell on CT175 (as the openclaw user
#   or root), or via SSH, BEFORE sending the next message to either agent.
#   Running it while an agent turn is in-flight may corrupt state.
#
# SESSION KEYS RESET
#   main agent:     agent:main:matrix:channel:!FKZTkwAIkROBtdHyCl:matrix.ryankennedy.dev
#   architect agent: agent:architect:matrix:channel:!FKZTkwAIkROBtdHyCl:matrix.ryankennedy.dev
#
# USAGE
#   bash scripts/reset-drafting-table.sh [--dry-run]
#
# REQUIREMENTS
#   jq must be installed; python3 is a fallback if jq is absent.

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[dry-run] No files will be modified."
fi

AGENTS_BASE="/home/openclaw/.openclaw/agents"
TIMESTAMP="$(date -u +%Y-%m-%dT%H-%M-%S.%3NZ)"

declare -A AGENT_KEYS
AGENT_KEYS["main"]="agent:main:matrix:channel:!FKZTkwAIkROBtdHyCl:matrix.ryankennedy.dev"
AGENT_KEYS["architect"]="agent:architect:matrix:channel:!FKZTkwAIkROBtdHyCl:matrix.ryankennedy.dev"

reset_session() {
  local agent="$1"
  local session_key="$2"
  local sessions_dir="${AGENTS_BASE}/${agent}/sessions"
  local sessions_json="${sessions_dir}/sessions.json"

  echo "--- [${agent}] ---"

  if [[ ! -f "$sessions_json" ]]; then
    echo "  sessions.json not found at ${sessions_json} — skipping"
    return
  fi

  # sessions.json is a flat dict: { "<session_key>": { sessionId, sessionFile, ... }, ... }
  local session_file session_id
  if command -v jq &>/dev/null; then
    session_file=$(jq -r --arg key "$session_key" '.[$key].sessionFile // empty' "$sessions_json" 2>/dev/null || true)
    session_id=$(jq -r --arg key "$session_key" '.[$key].sessionId // empty' "$sessions_json" 2>/dev/null || true)
  else
    read -r session_id session_file < <(python3 -c "
import json, sys
data = json.load(open('${sessions_json}'))
entry = data.get('${session_key}', {})
print(entry.get('sessionId', ''), entry.get('sessionFile', ''))
" 2>/dev/null || echo "")
  fi

  if [[ -z "$session_id" ]]; then
    echo "  Session key not found in store: ${session_key}"
    return
  fi

  echo "  Session ID: ${session_id}"

  # Prefer the sessionFile path from the store; fall back to constructed path
  local src="${session_file:-${sessions_dir}/${session_id}.jsonl}"
  local dst="${src}.reset.${TIMESTAMP}"

  if [[ ! -f "$src" ]]; then
    echo "  Transcript file not found (may already be reset): ${src}"
    return
  fi

  if $DRY_RUN; then
    echo "  [dry-run] Would rename: ${src}"
    echo "         -> ${dst}"
  else
    mv "$src" "$dst"
    echo "  Reset: ${src}"
    echo "     -> ${dst}"
  fi
}

for agent in main architect; do
  reset_session "$agent" "${AGENT_KEYS[$agent]}"
done

echo ""
if $DRY_RUN; then
  echo "Dry run complete. Re-run without --dry-run to apply."
else
  echo "Done. Both sessions will start fresh on next message."
fi