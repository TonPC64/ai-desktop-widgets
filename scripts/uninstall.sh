#!/bin/bash
set -euo pipefail

WIDGET_DIR="$HOME/Library/Application Support/Übersicht/widgets"
TARGETS=(
  "$WIDGET_DIR/claude-status.widget"
  "$WIDGET_DIR/copilot-status.widget"
  "$WIDGET_DIR/codex-status.widget"
  "$HOME/.local/share/ai-desktop-widgets"
  "$HOME/Library/LaunchAgents/com.ai-desktop-widgets.ubersicht.plist"
)

for target in "${TARGETS[@]}"; do
  if [ -e "$target" ] || [ -L "$target" ]; then
    rm -rf "$target"
    echo "Removed: $target"
  else
    echo "Absent: $target"
  fi
done
