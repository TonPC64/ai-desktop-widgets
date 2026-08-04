#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIDGET_DIR="$HOME/Library/Application Support/Übersicht/widgets"
TARGETS=(
  "$WIDGET_DIR/claude-status.widget"
  "$WIDGET_DIR/copilot-status.widget"
  "$WIDGET_DIR/codex-status.widget"
  "$WIDGET_DIR/agy-status.widget"
  "$HOME/.local/share/ai-desktop-widgets"
  "$HOME/Library/LaunchAgents/com.ai-desktop-widgets.ubersicht.plist"
)

if command -v node >/dev/null 2>&1; then
  node "$ROOT/scripts/install-pet-hooks.js" --uninstall
else
  echo "Warning: node unavailable; Claude hooks were not removed" >&2
fi

for target in "${TARGETS[@]}"; do
  if [ -e "$target" ] || [ -L "$target" ]; then
    rm -rf "$target"
    echo "Removed: $target"
  else
    echo "Absent: $target"
  fi
done
