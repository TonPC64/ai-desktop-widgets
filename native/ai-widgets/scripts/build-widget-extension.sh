#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${COPILOT_WIDGET_OUTPUT:-$ROOT/dist/AI Widgets.appex}"
BUILD_NUMBER="${COPILOT_WIDGET_BUILD_NUMBER:-$(date '+%y%m%d%H%M%S')}"
DERIVED="$(mktemp -d "${TMPDIR:-/tmp}/copilot-widget-xcode.XXXXXX")"
trap 'rm -rf "$DERIVED"' EXIT

xcodebuild -project "$ROOT/AIWidgetsExtension.xcodeproj" \
    -scheme AIWidgetsExtension -configuration Release \
    -derivedDataPath "$DERIVED" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGNING_ALLOWED=NO build >/dev/null

rm -rf "$OUTPUT"
ditto --norsrc "$DERIVED/Build/Products/Release/AI Widgets.appex" "$OUTPUT"
/usr/bin/xattr -cr "$OUTPUT"
codesign --force --sign - --entitlements "$ROOT/WidgetExtension/CopilotStatusWidget.entitlements" "$OUTPUT"
codesign --verify --strict --verbose=2 "$OUTPUT"
