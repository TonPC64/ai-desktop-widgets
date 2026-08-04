#!/bin/bash
# Data source for the Copilot CLI desktop widget. Reads local session usage
# straight out of ~/.copilot/session-store.db (SQLite) — no external API,
# no ccusage-style CLI needed; sqlite3 ships with macOS.
#
# Output: {"bins":[{bucket,model,tok}...],"todayArr":[{requests,tokens,aiu}],
#          "monthArr":[{requests,tokens,aiu}],"limitAiu":number}
# monthArr covers the current calendar month to date, matching how Copilot
# quotas reset monthly.
# aiu = total_nano_aiu / 1e9, i.e. GitHub's "AI Units" billing meter. There
# is no published nano-AIU-to-USD rate, so this is reported as-is rather
# than converted into an invented dollar figure.
# limitAiu is optional and user-configured (monthly AIU budget target).
# If COPILOT_BUDGET_ORG is set and `gh` has admin:org/billing-manager access,
# the limit is auto-fetched from GitHub's official Copilot budgets API:
#   GET /organizations/{org}/settings/billing/budgets?scope=multi_user_customer
# (1 AI credit = $0.01, so credits = effective_budget.budget_amount * 100).
# That result is cached for LIMIT_TTL seconds to avoid hammering the API on
# every widget refresh. COPILOT_MONTHLY_AIU_LIMIT always overrides everything.
# Bucket-filling and per-model aggregation happen in the widget's JS, same
# division of labor as the Claude Code widget's data script.
set -u

DB="$HOME/.copilot/session-store.db"
CACHE_DIR="$HOME/.cache/copilot-touchbar"
CACHE="$CACHE_DIR/data.json"
TTL=60
LIMIT_CACHE="$CACHE_DIR/limit-aiu.json"
LIMIT_TTL=3600
# Copilot Business screenshot shows a 126,000 monthly credit limit.
# Env var still wins so you can override any time.
DEFAULT_BUSINESS_LIMIT_AIU=126000

# Fetches the org's multi-user Copilot budget via GitHub's REST API and
# converts it to AI credits. Prints nothing and returns non-zero on any
# failure (missing gh, no auth, no admin/billing-manager access, no budget
# configured, etc.) so callers can fall back silently.
fetch_api_limit_aiu() {
  local org="$1"
  command -v gh >/dev/null 2>&1 || return 1
  gh api "organizations/$org/settings/billing/budgets?scope=multi_user_customer" 2>/dev/null \
    | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    amt = d.get("effective_budget", {}).get("budget_amount")
    if amt is None:
        sys.exit(1)
    print(float(amt) * 100)
except Exception:
    sys.exit(1)
' 2>/dev/null
}

mkdir -p "$CACHE_DIR"

now=$(date +%s)
if [ -f "$CACHE" ]; then
  mtime=$(stat -f %m "$CACHE" 2>/dev/null || echo 0)
  if [ $((now - mtime)) -lt "$TTL" ]; then
    cat "$CACHE"
    exit 0
  fi
fi

SQLITE="$(command -v sqlite3 || echo /usr/bin/sqlite3)"
if [ ! -x "$SQLITE" ] || [ ! -f "$DB" ]; then
  echo '{"bins":[],"todayArr":[],"monthArr":[],"limitAiu":0}'
  exit 0
fi

LIMIT_AIU=""
if [ -n "${COPILOT_MONTHLY_AIU_LIMIT:-}" ]; then
  LIMIT_AIU="$COPILOT_MONTHLY_AIU_LIMIT"
elif [ -n "${COPILOT_BUDGET_ORG:-}" ]; then
  cache_age=999999
  if [ -f "$LIMIT_CACHE" ]; then
    cache_age=$(( $(date +%s) - $(stat -f %m "$LIMIT_CACHE" 2>/dev/null || echo 0) ))
  fi
  if [ "$cache_age" -lt "$LIMIT_TTL" ]; then
    LIMIT_AIU=$(cat "$LIMIT_CACHE" 2>/dev/null)
  else
    API_LIMIT="$(fetch_api_limit_aiu "$COPILOT_BUDGET_ORG")"
    if [ -n "$API_LIMIT" ]; then
      LIMIT_AIU="$API_LIMIT"
      echo "$LIMIT_AIU" > "$LIMIT_CACHE"
    elif [ -f "$LIMIT_CACHE" ]; then
      LIMIT_AIU=$(cat "$LIMIT_CACHE" 2>/dev/null)
    fi
  fi
fi
LIMIT_AIU="${LIMIT_AIU:-${COPILOT_BUSINESS_MONTHLY_AIU_LIMIT:-$DEFAULT_BUSINESS_LIMIT_AIU}}"
if ! [[ "$LIMIT_AIU" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  LIMIT_AIU="$DEFAULT_BUSINESS_LIMIT_AIU"
fi

# -readonly: never touch the live WAL-mode DB Copilot CLI itself is writing to.
BINS=$("$SQLITE" -readonly -json "$DB" "
  SELECT
    (CAST(strftime('%s', created_at) AS INTEGER) / 1800) * 1800 AS bucket,
    model,
    SUM(COALESCE(input_tokens,0) + COALESCE(output_tokens,0)) AS tok
  FROM assistant_usage_events
  WHERE created_at >= datetime('now', '-1 day')
  GROUP BY bucket, model
  ORDER BY bucket ASC;
" 2>/dev/null)
[ -z "$BINS" ] && BINS="[]"

TODAY=$("$SQLITE" -readonly -json "$DB" "
  SELECT COUNT(*) AS requests,
    SUM(COALESCE(input_tokens,0) + COALESCE(output_tokens,0)) AS tokens,
    SUM(COALESCE(total_nano_aiu,0)) / 1e9 AS aiu
  FROM assistant_usage_events
  WHERE created_at >= datetime('now', 'start of day');
" 2>/dev/null)
[ -z "$TODAY" ] && TODAY="[]"

MONTH=$("$SQLITE" -readonly -json "$DB" "
  SELECT COUNT(*) AS requests,
    SUM(COALESCE(input_tokens,0) + COALESCE(output_tokens,0)) AS tokens,
    SUM(COALESCE(total_nano_aiu,0)) / 1e9 AS aiu
  FROM assistant_usage_events
  WHERE created_at >= datetime('now', 'start of month');
" 2>/dev/null)
[ -z "$MONTH" ] && MONTH="[]"

printf '{"bins":%s,"todayArr":%s,"monthArr":%s,"limitAiu":%s}' "$BINS" "$TODAY" "$MONTH" "$LIMIT_AIU" > "$CACHE"
cat "$CACHE"
