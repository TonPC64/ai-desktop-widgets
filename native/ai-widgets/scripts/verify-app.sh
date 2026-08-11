#!/usr/bin/env bash
set -euo pipefail

app="${1:?app path required}"
metadata="$app/Contents/PlugIns/AI Widgets.appex/Contents/Resources/Metadata.appintents/extract.actionsdata"
test -x "$app/Contents/MacOS/CopilotWidgetHost"
test -x "$app/Contents/Resources/node_modules/.bin/ccusage"
test -f "$app/Contents/Resources/scripts/claude-usage-windows.js"
test -d "$app/Contents/PlugIns/AI Widgets.appex"
test -f "$metadata"
grep -q '"name":"provider"' "$metadata"
grep -q '"isOptional":true' "$metadata"
! grep -q 'LNValueTypeSpecificMetadataKeyDefaultValue' "$metadata"
plutil -extract LSUIElement raw "$app/Contents/Info.plist" | grep -qx true
codesign --verify --deep --strict --verbose=2 "$app"
