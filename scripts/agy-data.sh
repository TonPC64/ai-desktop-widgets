#!/bin/bash
# agy-data.sh — Antigravity CLI data collector for the Übersicht desktop widget.
# Uses the macOS system Python — no nvm/asdf shims — safe for Übersicht.

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"

AGY_DIR="${HOME}/.gemini/antigravity-cli"
HISTORY="${AGY_DIR}/history.jsonl"
META="${AGY_DIR}/cache/conversation_metadata.json"
SETTINGS="${AGY_DIR}/settings.json"
CACHE_DIR="${HOME}/.cache/agy-widget"
CACHE_FILE="${CACHE_DIR}/data.json"
CACHE_TTL=15

mkdir -p "$CACHE_DIR"

# Serve cached result if still fresh
if [ -f "$CACHE_FILE" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if [ "$age" -lt "$CACHE_TTL" ]; then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

# --- parse local data with macOS's system Python ---
now_ms=$(( $(date +%s) * 1000 ))
slot_ms=1800000
start_slot=$(( (now_ms / slot_ms - 47) * slot_ms ))
SYSPYTHON=/usr/bin/python3

"$SYSPYTHON" - "$HISTORY" "$META" "$SETTINGS" "$CACHE_FILE" "$now_ms" "$slot_ms" "$start_slot" <<'PYEOF'
import sys, json

history_path, meta_path, settings_path, cache_file, now_ms_s, slot_ms_s, start_slot_s = sys.argv[1:]
now_ms     = int(now_ms_s)
slot_ms    = int(slot_ms_s)
start_slot = int(start_slot_s)

since24 = now_ms - 86_400_000
since7d = now_ms - 7 * 86_400_000

# history
entries = []
try:
    with open(history_path) as f:
        for line in f:
            line = line.strip()
            if line:
                try: entries.append(json.loads(line))
                except: pass
except: pass

settings = {}
try:
    with open(settings_path) as f: settings = json.load(f)
except: pass

meta_convs = {}
try:
    with open(meta_path) as f:
        meta_convs = json.load(f).get("conversations", {})
except: pass

bins_map = {}
for e in entries:
    t = e.get("timestamp", 0)
    if t >= start_slot:
        b = (t // slot_ms) * slot_ms
        bins_map[b] = bins_map.get(b, 0) + 1

bins = [{"t": start_slot + i * slot_ms, "count": bins_map.get(start_slot + i * slot_ms, 0)} for i in range(48)]

last24      = [e for e in entries if e.get("timestamp", 0) >= since24]
last7d      = [e for e in entries if e.get("timestamp", 0) >= since7d]
total_steps = sum(c.get("summary", {}).get("NumSteps", 0) for c in meta_convs.values())

def conv_ts(c):
    ua = c.get("summary", {}).get("UpdatedAt", "")
    try:
        from datetime import datetime, timezone
        return datetime.fromisoformat(ua.replace("Z", "+00:00")).timestamp() * 1000
    except: return 0

current_conv = None
if meta_convs:
    latest = max(meta_convs.values(), key=conv_ts)
    s = latest.get("summary", {})
    current_conv = {
        "preview":   s.get("Preview", ""),
        "steps":     s.get("NumSteps", 0),
        "workspace": (s.get("WorkspaceURIs") or [""])[0].replace("file://", ""),
        "updatedAt": s.get("UpdatedAt", ""),
    }

last_entry = entries[-1] if entries else {}

out = json.dumps({
    "model":        settings.get("model", "unknown"),
    "bins":         bins,
    "prompts24h":   len(last24),
    "prompts7d":    len(last7d),
    "totalPrompts": len(entries),
    "totalConvs":   len(meta_convs),
    "totalSteps":   total_steps,
    "lastPrompt":   last_entry.get("display", ""),
    "lastTs":       last_entry.get("timestamp", 0),
    "currentConv":  current_conv,
})

with open(cache_file, "w") as f:
    f.write(out)
print(out)
PYEOF
