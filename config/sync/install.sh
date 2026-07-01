#!/bin/sh
# Install homelab sync units on both hosts.
# Run from the repo root or config/sync/.
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$(uname -s)" in
  Linux)
    echo "Installing systemd units on CT175..."
    sudo cp "$SCRIPT_DIR/homelab-sync.service" /etc/systemd/system/
    sudo cp "$SCRIPT_DIR/homelab-sync.timer" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable --now homelab-sync.timer
    echo "CT175 timer installed and started."
    ;;
  Darwin)
    echo "Installing launchd plists on Mac..."
    cp "$SCRIPT_DIR/ai.openclaw.homelab-sync-omega.plist" ~/Library/LaunchAgents/
    cp "$SCRIPT_DIR/ai.openclaw.homelab-sync-hermes.plist" ~/Library/LaunchAgents/
    launchctl unload ~/Library/LaunchAgents/ai.openclaw.homelab-sync-omega.plist 2>/dev/null || true
    launchctl unload ~/Library/LaunchAgents/ai.openclaw.homelab-sync-hermes.plist 2>/dev/null || true
    launchctl load ~/Library/LaunchAgents/ai.openclaw.homelab-sync-omega.plist
    launchctl load ~/Library/LaunchAgents/ai.openclaw.homelab-sync-hermes.plist
    echo "Mac launchd agents loaded."
    ;;
esac
