#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_APP="$ROOT/dist/AI Widgets.app"
TARGET_APP="$HOME/Applications/AI Widgets.app"
EXTENSION="$TARGET_APP/Contents/PlugIns/AI Widgets.appex"

bash "$ROOT/scripts/build-app.sh"
mkdir -p "$HOME/Applications"
pkill -x CopilotWidgetHost >/dev/null 2>&1 || true
rm -rf "$TARGET_APP"
ditto --norsrc "$SOURCE_APP" "$TARGET_APP"
pluginkit -r "$EXTENSION" >/dev/null 2>&1 || true
pluginkit -a "$EXTENSION"
open -gj "$TARGET_APP"

echo "Installed AI Widgets. Add it from Widget Gallery."
