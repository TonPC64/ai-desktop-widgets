#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.cache/claude-touchbar"
printf 'not json\n' > "$TMP/.cache/claude-touchbar/graph.txt"
HOME="$TMP" bash "$ROOT/scripts/claude-status.sh" graph | node -e '
  let input = "";
  process.stdin.on("data", (chunk) => input += chunk).on("end", () => JSON.parse(input));
'
