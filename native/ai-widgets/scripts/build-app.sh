#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$ROOT/../.." && pwd)"
DIST_APP="$ROOT/dist/AI Widgets.app"
BUILD_NUMBER="${COPILOT_WIDGET_BUILD_NUMBER:-$(date '+%y%m%d%H%M%S')}"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/copilot-widget.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

swift build --package-path "$ROOT" -c release
BIN_DIR="$(swift build --package-path "$ROOT" -c release --show-bin-path)"
APP="$STAGE/AI Widgets.app"
APPEX="$APP/Contents/PlugIns/AI Widgets.appex"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/scripts" "$APPEX/Contents/MacOS"
install -m 755 "$BIN_DIR/CopilotWidgetHost" "$APP/Contents/MacOS/CopilotWidgetHost"
install -m 644 "$ROOT/Resources/AIWidgets.icns" "$APP/Contents/Resources/AIWidgets.icns"
install -m 755 "$PROJECT_ROOT/scripts/copilot-data.sh" "$APP/Contents/Resources/scripts/copilot-data.sh"
install -m 755 "$PROJECT_ROOT/scripts/claude-status.sh" "$APP/Contents/Resources/scripts/claude-status.sh"
install -m 755 "$PROJECT_ROOT/scripts/status.js" "$APP/Contents/Resources/scripts/status.js"
install -m 644 "$PROJECT_ROOT/scripts/claude-usage-windows.js" "$APP/Contents/Resources/scripts/claude-usage-windows.js"
install -m 755 "$PROJECT_ROOT/scripts/codex-data.sh" "$APP/Contents/Resources/scripts/codex-data.sh"
install -m 644 "$PROJECT_ROOT/scripts/codex-data.js" "$APP/Contents/Resources/scripts/codex-data.js"
test -x "$PROJECT_ROOT/node_modules/.bin/ccusage" || { echo "Missing locked ccusage dependency; run npm install first." >&2; exit 1; }
ditto --norsrc "$PROJECT_ROOT/node_modules" "$APP/Contents/Resources/node_modules"
cp "$ROOT/Resources/Host-Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"

COPILOT_WIDGET_OUTPUT="$APPEX" COPILOT_WIDGET_BUILD_NUMBER="$BUILD_NUMBER" \
    bash "$ROOT/scripts/build-widget-extension.sh"

/usr/bin/xattr -cr "$APP" 2>/dev/null || true
codesign --force --sign - "$APP"

rm -rf "$DIST_APP"
mkdir -p "$(dirname "$DIST_APP")"
ditto --norsrc "$APP" "$DIST_APP"
bash "$ROOT/scripts/verify-app.sh" "$DIST_APP"

echo "Built $DIST_APP"
