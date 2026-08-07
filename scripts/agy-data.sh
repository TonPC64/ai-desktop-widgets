#!/bin/bash
# agy-data.sh — Antigravity CLI data collector for the Übersicht desktop widget.
# Uses the macOS system Python — no nvm/asdf shims — safe for Übersicht.

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:${HOME}/.local/bin"

AGY_DIR="${HOME}/.gemini/antigravity-cli"
HISTORY="${AGY_DIR}/history.jsonl"
META="${AGY_DIR}/cache/conversation_metadata.json"
SETTINGS="${AGY_DIR}/settings.json"
CACHE_DIR="${HOME}/.cache/agy-widget"
CACHE_FILE="${CACHE_DIR}/data.json"
QUOTA_CACHE="${CACHE_DIR}/quota.tsv"
CACHE_TTL=15
QUOTA_TTL=300

mkdir -p "$CACHE_DIR"

# Serve cached result if still fresh
if [ -f "$CACHE_FILE" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if [ "$age" -lt "$CACHE_TTL" ]; then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

# Refresh quota cache if stale
if [ -f "$QUOTA_CACHE" ]; then
  qage=$(( $(date +%s) - $(stat -f %m "$QUOTA_CACHE" 2>/dev/null || echo 0) ))
else
  qage=$QUOTA_TTL
fi
if [ "$qage" -ge "$QUOTA_TTL" ]; then
  agy -p "/quota" --print-timeout 10s 2>/dev/null > "$QUOTA_CACHE" || true
fi

# --- parse local data with macOS's system Python ---
now_ms=$(( $(date +%s) * 1000 ))
slot_ms=1800000
start_slot=$(( (now_ms / slot_ms - 47) * slot_ms ))
SYSPYTHON=/usr/bin/python3

"$SYSPYTHON" - "$HISTORY" "$META" "$SETTINGS" "$CACHE_FILE" "$QUOTA_CACHE" "$now_ms" "$slot_ms" "$start_slot" <<'PYEOF'
import sys, json, re

history_path, meta_path, settings_path, cache_file, quota_cache, now_ms_s, slot_ms_s, start_slot_s = sys.argv[1:]
now_ms     = int(now_ms_s)
slot_ms    = int(slot_ms_s)
start_slot = int(start_slot_s)

since24 = now_ms - 86_400_000
since7d = now_ms - 7 * 86_400_000

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

# --- parse quota TSV from agy /quota output ---
# Format: "Group Name\tWeekly Limit Remaining\tPERCENT%\tISO_RESET_TIME"
quota = {
    "gemini":     {"pct": None, "resetTs": 0},
    "claude_gpt": {"pct": None, "resetTs": 0},
}
try:
    from datetime import datetime, timezone as tz
    with open(quota_cache) as f:
        for line in f:
            parts = [p.strip() for p in line.strip().split('\t')]
            if len(parts) < 3: continue
            group_name = parts[0].lower()
            pct_str    = parts[2].rstrip('%') if len(parts) > 2 else ""
            reset_str  = parts[3] if len(parts) > 3 else ""
            if 'gemini' in group_name:
                key = 'gemini'
            elif 'claude' in group_name or 'gpt' in group_name:
                key = 'claude_gpt'
            else:
                continue
            try:
                quota[key]['pct'] = int(float(pct_str))
            except: pass
            try:
                dt = datetime.fromisoformat(reset_str.replace('Z', '+00:00'))
                quota[key]['resetTs'] = int(dt.timestamp() * 1000)
            except: pass
except: pass

last_entry = entries[-1] if entries else {}

out = json.dumps({
    "model":         settings.get("model", "unknown"),
    "bins":          bins,
    "prompts24h":    len(last24),
    "prompts7d":     len(last7d),
    "totalConvs":    len(meta_convs),
    "totalSteps":    total_steps,
    "lastTs":        last_entry.get("timestamp", 0),
    "geminiPct":     quota["gemini"]["pct"],
    "geminiResetTs": quota["gemini"]["resetTs"],
    "claudeGptPct":  quota["claude_gpt"]["pct"],
    "claudeGptResetTs": quota["claude_gpt"]["resetTs"],
})

with open(cache_file, "w") as f:
    f.write(out)
print(out)
PYEOF
