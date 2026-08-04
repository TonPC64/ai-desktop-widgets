#!/usr/bin/env bash
set -euo pipefail

app="${1:?app path required}"
test -x "$app/Contents/MacOS/CopilotWidgetHost"
test -d "$app/Contents/PlugIns/AI Widgets.appex"
plutil -extract LSUIElement raw "$app/Contents/Info.plist" | grep -qx true
codesign --verify --deep --strict --verbose=2 "$app"
