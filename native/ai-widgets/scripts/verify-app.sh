#!/usr/bin/env bash
set -euo pipefail

app="${1:?app path required}"
metadata="$app/Contents/PlugIns/AI Widgets.appex/Contents/Resources/Metadata.appintents/extract.actionsdata"
test -x "$app/Contents/MacOS/CopilotWidgetHost"
test -f "$app/Contents/Resources/AIWidgets.icns"
test -x "$app/Contents/Resources/node_modules/.bin/ccusage"
test -f "$app/Contents/Resources/scripts/claude-usage-windows.js"
test -d "$app/Contents/PlugIns/AI Widgets.appex"
test -f "$app/Contents/PlugIns/AI Widgets.appex/Contents/Resources/AppIcon.icns"
test -f "$app/Contents/PlugIns/AI Widgets.appex/Contents/Resources/Assets.car"
test -f "$metadata"
grep -q '"name":"provider"' "$metadata"
grep -q '"isOptional":true' "$metadata"
! grep -q 'LNValueTypeSpecificMetadataKeyDefaultValue' "$metadata"
plutil -extract LSUIElement raw "$app/Contents/Info.plist" | grep -qx true
plutil -extract CFBundleIconFile raw "$app/Contents/Info.plist" | grep -qx AIWidgets
plutil -extract CFBundleIconFile raw "$app/Contents/PlugIns/AI Widgets.appex/Contents/Info.plist" | grep -qx AppIcon
plutil -extract CFBundleIconName raw "$app/Contents/PlugIns/AI Widgets.appex/Contents/Info.plist" | grep -qx AppIcon
codesign --verify --deep --strict --verbose=2 "$app"
