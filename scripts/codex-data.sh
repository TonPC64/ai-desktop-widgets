#!/bin/bash
# Local data source for the Codex Übersicht widget. Codex session logs contain
# token counters, model context, and rate-limit windows; the Node collector only
# reads those fields and never copies prompts or responses.
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

for NODE in \
  "$(command -v node 2>/dev/null || true)" \
  /opt/homebrew/bin/node \
  /usr/local/bin/node \
  "$HOME/.nvm/versions/node/current/bin/node"
do
  if [ -n "$NODE" ] && [ -x "$NODE" ]; then
    exec "$NODE" "$DIR/codex-data.js"
  fi
done

echo '{"bins":[],"quota":[],"current":null,"todayTokens":0,"observedAt":null,"error":"node unavailable"}'
