#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$HOME/.local/share/ai-desktop-widgets"
WIDGET_DIR="$HOME/Library/Application Support/Übersicht/widgets"
WIDGETS="all"

usage() {
  cat <<'EOF'
Usage: scripts/install.sh [--only widget] [--widgets claude,copilot,codex]

Install Übersicht desktop widgets.

Options:
  --only widget                 Install the widget component (the only component).
  --widgets NAME[,NAME...]      Choose claude, copilot, codex, all, or both.
  -h, --help                    Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --only)
      [ "$#" -ge 2 ] || { echo "--only needs a component" >&2; exit 2; }
      [ "$2" = widget ] || { echo "only 'widget' is supported" >&2; exit 2; }
      shift 2
      ;;
    --widgets)
      [ "$#" -ge 2 ] || { echo "--widgets needs a selection" >&2; exit 2; }
      WIDGETS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$WIDGETS" in
  all) selected=(claude copilot codex) ;;
  both) selected=(claude copilot) ;;
  *)
    IFS=, read -r -a selected <<<"$WIDGETS"
    [ "${#selected[@]}" -gt 0 ] || { echo "no widgets selected" >&2; exit 2; }
    for widget in "${selected[@]}"; do
      case "$widget" in claude|copilot|codex) ;; *) echo "unknown widget: $widget" >&2; exit 2 ;; esac
    done
    ;;
esac

# This installer no longer creates agents, but retain the legacy warning so a
# restrictive managed Mac does not turn installation into a hard failure.
if [ -e "$HOME/Library/LaunchAgents" ] && [ ! -w "$HOME/Library/LaunchAgents" ]; then
  echo "warning: ~/Library/LaunchAgents is not writable; continuing without LaunchAgent changes" >&2
fi

mkdir -p "$RUNTIME/scripts" "$WIDGET_DIR"
runtime_files=()
for widget in "${selected[@]}"; do
  case "$widget" in
    claude) runtime_files+=(widget-data.sh claude-status.sh status.js pet-hook.sh install-pet-hooks.js) ;;
    copilot) runtime_files+=(copilot-data.sh) ;;
    codex) runtime_files+=(codex-data.sh codex-data.js) ;;
  esac
done

# Prune only files owned by this installer, so changing widget selections does
# not leave collectors for an unselected widget behind.
for file in widget-data.sh claude-status.sh claude-week.sh status.js pet-hook.sh \
  install-pet-hooks.js copilot-data.sh codex-data.sh codex-data.js install.sh; do
  rm -f "$RUNTIME/scripts/$file"
done
for file in "${runtime_files[@]}"; do
  cp "$ROOT/scripts/$file" "$RUNTIME/scripts/"
done

if [[ " ${selected[*]} " == *" claude "* ]]; then
  cp "$ROOT/package.json" "$ROOT/package-lock.json" "$RUNTIME/"
  npm install --omit=dev --prefix "$RUNTIME"
fi

for widget in "${selected[@]}"; do
  source_widget="$ROOT/ubersicht/${widget}-status.widget"
  target_widget="$WIDGET_DIR/${widget}-status.widget"
  cp -R "$source_widget" "$WIDGET_DIR/"
  runtime_path="$RUNTIME/scripts/${widget}"
  case "$widget" in
    claude) runtime_path="$RUNTIME/scripts/widget-data.sh" ;;
    copilot) runtime_path="$RUNTIME/scripts/copilot-data.sh" ;;
    codex) runtime_path="$RUNTIME/scripts/codex-data.sh" ;;
  esac
  tmp="$(mktemp)"
  sed "s|\$HOME/.local/share/claude-status-touch-bar/scripts/[^\"']*|$runtime_path|" \
    "$target_widget/index.jsx" >"$tmp"
  mv "$tmp" "$target_widget/index.jsx"
done

if [[ " ${selected[*]} " == *" claude "* ]]; then
  mkdir -p "$HOME/.claude"
  tmp="$(mktemp)"
  sed 's|claude-status-touch-bar/scripts/pet-hook.sh|ai-desktop-widgets/scripts/pet-hook.sh|g' \
    "$RUNTIME/scripts/install-pet-hooks.js" >"$tmp"
  mv "$tmp" "$RUNTIME/scripts/install-pet-hooks.js"
  CLAUDE_TOUCH_RUNTIME="$RUNTIME" node "$RUNTIME/scripts/install-pet-hooks.js"
fi

echo "Installed: ${selected[*]}"
