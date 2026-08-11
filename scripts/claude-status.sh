#!/bin/bash
# Claude status collector. Prints one line and exits.
# Caches output so a slow read does not block the widget.
#   claude-status.sh block   (default, cached 30s)
#   claude-status.sh week    (cached 300s)
#   claude-status.sh menu    (cached 30s)
#   claude-status.sh graph   (cached 300s)
set -u

MODE="${1:-block}"
CACHE_KEY="${2:-$MODE}"
# ${BASH_SOURCE[0]:-$0}: some launchers execute script contents via bash -c,
# where BASH_SOURCE is unset and set -u would abort.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
CACHE_DIR="${HOME}/.cache/claude-touchbar"
CACHE="${CACHE_DIR}/${CACHE_KEY}.txt"
TTL=30
case "$MODE" in week|graph) TTL=300 ;; esac

mkdir -p "$CACHE_DIR"

# Pick a node binary: PATH first, then nvm/homebrew fallbacks. Each candidate
# is test-run:
# a broken install (e.g. homebrew node missing its icu4c dylib) must not win.
NODE=""
for candidate in "$(command -v node 2>/dev/null || true)" \
    "$HOME"/.nvm/versions/node/*/bin/node \
    /opt/homebrew/bin/node /usr/local/bin/node; do
  if [ -n "$candidate" ] && [ -x "$candidate" ] && \
     "$candidate" -e 'process.exit(0)' >/dev/null 2>&1; then
    NODE="$candidate"
    break
  fi
done
if [ -z "$NODE" ]; then
  [ "$MODE" = graph ] && echo '{}' || echo "✳ no node"
  exit 0
fi

now=$(date +%s)
valid_cache() {
  [ "$MODE" != graph ] || printf '%s' "$(cat "$CACHE")" | "$NODE" -e '
    let input = "";
    process.stdin.on("data", (chunk) => input += chunk).on("end", () => {
      const value = JSON.parse(input);
      if (!value || Array.isArray(value) || typeof value !== "object") process.exit(1);
    });
  ' 2>/dev/null
}
if [ -f "$CACHE" ]; then
  age=$(( now - $(stat -f %m "$CACHE") ))
  if [ "$age" -lt "$TTL" ] && valid_cache; then
    cat "$CACHE"
    exit 0
  fi
fi

out="$("$NODE" "$DIR/scripts/status.js" "$MODE" 2>/dev/null)"
if [ -n "$out" ]; then
  printf '%s\n' "$out" | tee "$CACHE"
else
  # Fall back to stale cache rather than flashing an empty button.
  [ -f "$CACHE" ] && valid_cache && cat "$CACHE" || { [ "$MODE" = graph ] && echo '{}' || echo "✳ …"; }
fi
