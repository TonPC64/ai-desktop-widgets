#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_TEST="$(mktemp -d)"
BIN_TEST="$HOME_TEST/bin"
mkdir -p "$BIN_TEST"
ln -s /usr/bin/true "$BIN_TEST/npm"

PATH="$BIN_TEST:$PATH" HOME="$HOME_TEST" bash "$ROOT/scripts/install.sh" --widgets claude
PATH="$BIN_TEST:$PATH" HOME="$HOME_TEST" bash "$ROOT/scripts/install.sh" --widgets copilot

test -d "$HOME_TEST/Library/Application Support/Übersicht/widgets/claude-status.widget"
test -d "$HOME_TEST/Library/Application Support/Übersicht/widgets/copilot-status.widget"
test -e "$HOME_TEST/.local/share/ai-desktop-widgets/scripts/claude-status.sh"
test -e "$HOME_TEST/.local/share/ai-desktop-widgets/scripts/copilot-data.sh"
