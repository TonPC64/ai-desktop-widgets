# Native Claude Window Cycle

## Goal

Make the native Claude dashboard useful for both Anthropic OAuth and AWS Bedrock users. Clicking the Claude headline cycles `5H → 7D → This month`, and the headline, supporting usage, and token graph all switch to the same period.

## Presentation

- Bedrock or missing quota data: show period cost as the headline and token count as detail. Never render a synthetic `0%` quota.
- Anthropic OAuth: retain real 5H/7D quota percentages when available; month remains cost and tokens.
- The selected period label is always visible.
- The period is shared by native Claude widgets through the existing WidgetKit intent/UserDefaults pattern.
- Claude chart and legend colors match Übersicht by model family: Fable `#3987E5`, Opus `#199E70`, Sonnet `#C98500`, Haiku `#E66767`, other `#898781`.
- Copilot and Codex presentation and colors remain unchanged.

## Data

Extend the Claude graph payload without removing its existing fields:

- `5H`: current active block totals and token bins covering five hours.
- `7D`: ccusage seven-day totals and token bins covering seven days.
- `month`: ccusage month totals and daily token bins from the local month boundary.

Collect matching model-token events once from the earliest required date, then aggregate them into each window. Normalize these windows into the provider snapshot so WidgetKit performs no shell work.

If no events exist for a period, preserve its totals and return an empty graph. Missing cost or token data displays `--`, not zero usage.

## Interaction

Add one Claude-specific AppIntent that advances the stored period and reloads the existing widget kind. The Claude headline is the button target. Timeline entries read the selected period, derive the matching headline/detail, and pass only that period’s buckets to the chart.

## Testing

- Collector test: events aggregate into correct 5H, 7D, and month windows.
- Snapshot test: missing quota does not become `0%`; Bedrock uses cost/tokens.
- Cycle test: period order wraps from month to 5H.
- Palette test: Claude model families resolve to the Übersicht color tokens.
- Run all Swift and relevant JavaScript checks, build/sign the native app, reinstall, and verify the live Claude timeline.

## Scope

Included: native Claude period cycling, period-specific local usage graphs, truthful OAuth/Bedrock presentation, and Claude palette parity.

Excluded: AWS budget API integration, per-widget independent cycle state, changes to the Übersicht widget, and fabricated quota percentages.
