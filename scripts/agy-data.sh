#!/bin/bash
# agy-data.sh — Antigravity CLI data collector for the Übersicht desktop widget.
# Reads ~/.gemini/antigravity-cli local data and emits a JSON blob.
# No network calls; entirely local.

set -euo pipefail

CACHE_DIR="${HOME}/.cache/agy-widget"
CACHE_FILE="${CACHE_DIR}/data.json"
CACHE_TTL=15  # seconds

mkdir -p "$CACHE_DIR"

# Serve cached result if still fresh
if [ -f "$CACHE_FILE" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if [ "$age" -lt "$CACHE_TTL" ]; then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

python3 - > "$CACHE_FILE" <<'PYEOF'
import json, os
from datetime import datetime, timezone

AGY_DIR   = os.path.expanduser("~/.gemini/antigravity-cli")
HISTORY   = os.path.join(AGY_DIR, "history.jsonl")
META      = os.path.join(AGY_DIR, "cache", "conversation_metadata.json")
SETTINGS  = os.path.join(AGY_DIR, "settings.json")

now_ms = datetime.now(timezone.utc).timestamp() * 1000

# --- history ---
entries = []
try:
    with open(HISTORY) as f:
        for line in f:
            line = line.strip()
            if line:
                try: entries.append(json.loads(line))
                except: pass
except Exception: pass

# --- settings ---
settings = {}
try:
    with open(SETTINGS) as f: settings = json.load(f)
except Exception: pass

# --- conversation metadata ---
meta_convs = {}
try:
    with open(META) as f:
        meta_convs = json.load(f).get("conversations", {})
except Exception: pass

# --- 24h prompt-count bins (48 × 30 min slots) ---
slot_ms  = 30 * 60 * 1000
start_ms = (int(now_ms / slot_ms) - 47) * slot_ms
bins_map = {}
for e in entries:
    t = e.get("timestamp", 0)
    if t >= start_ms:
        b = int(t / slot_ms) * slot_ms
        bins_map[b] = bins_map.get(b, 0) + 1

bins = [{"t": start_ms + i * slot_ms, "count": bins_map.get(start_ms + i * slot_ms, 0)} for i in range(48)]

# --- aggregates ---
last24       = [e for e in entries if now_ms - e.get("timestamp", 0) < 86_400_000]
last7d       = [e for e in entries if now_ms - e.get("timestamp", 0) < 7 * 86_400_000]
total_steps  = sum(c.get("summary", {}).get("NumSteps", 0) for c in meta_convs.values())

def conv_updated_ms(c):
    ua = c.get("summary", {}).get("UpdatedAt", "")
    try: return datetime.fromisoformat(ua.replace("Z", "+00:00")).timestamp() * 1000
    except: return 0

active_convs = [c for c in meta_convs.values() if conv_updated_ms(c) > now_ms - 86_400_000]

# --- current (most recently updated) conversation ---
current_conv = None
if meta_convs:
    latest = max(meta_convs.values(), key=conv_updated_ms)
    s = latest.get("summary", {})
    current_conv = {
        "id":        s.get("ID", ""),
        "preview":   s.get("Preview", ""),
        "steps":     s.get("NumSteps", 0),
        "updatedAt": s.get("UpdatedAt", ""),
        "workspace": (s.get("WorkspaceURIs") or [""])[0].replace("file://", ""),
    }

last_entry = entries[-1] if entries else {}

print(json.dumps({
    "model":        settings.get("model", "unknown"),
    "bins":         bins,
    "prompts24h":   len(last24),
    "prompts7d":    len(last7d),
    "totalPrompts": len(entries),
    "totalConvs":   len(meta_convs),
    "activeConvs":  len(active_convs),
    "totalSteps":   total_steps,
    "lastPrompt":   last_entry.get("display", ""),
    "lastTs":       last_entry.get("timestamp", 0),
    "currentConv":  current_conv,
}))
PYEOF

cat "$CACHE_FILE"
