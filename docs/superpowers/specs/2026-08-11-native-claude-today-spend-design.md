# Native Claude Today and Spend Design

## Goal

Replace the native Claude widget's 5H period with Today and show period-matched spend whenever a real quota percentage is unavailable.

## Periods

The interaction cycle is exactly:

`Today → 7D → This month → Today`

- Today: local midnight through now.
- 7D: local midnight six days ago through now.
- This month: local month start through now.

An existing saved `fiveHour` selection migrates to Today.

## Presentation

Each selected period supplies its own headline, token detail, graph bins, graph domain, and label.

- Show a real OAuth quota percentage when that exact period has one.
- Otherwise show the matching ccusage spend.
- If spend is unavailable, show `--`; never synthesize `$0` or `0%`.
- Token details continue using compact units such as `K` and `M`.

Today and This month have no OAuth quota counterpart, so their headline is spend. The 7D headline uses the real 7D quota percentage when available and falls back to 7D spend otherwise.

## Collector

The Claude collector emits `usageWindows.today`, `usageWindows.sevenDay`, and `usageWindows.month`.

Event aggregation and ccusage totals use the same local calendar boundaries. Today uses today's daily total, 7D uses daily totals starting six calendar days ago, and month uses daily totals from the first day of the month. Missing ccusage output remains `null`.

Legacy Übersicht payload keys (`bins`, `block`, `week`, and `month`) remain unchanged.

## Native Model and UI

Rename the native first period from `fiveHour` to `today`, decode the new collector key, and preserve the existing AppIntent cycle mechanism. The widget displays `today`, `last 7d`, or `this month` and updates headline, detail, and graph together.

Copilot, Codex, provider selection, and Claude model colors remain unchanged.

## Verification

- Node tests cover local calendar boundaries, matching token/bin domains, and matching period costs.
- Swift tests cover cycle order, saved 5H migration, percentage preference, spend fallback, and unavailable spend.
- The full Swift suite and signed extension build pass.
- Fresh-install verification confirms one WidgetKit registration and three live Claude windows.
