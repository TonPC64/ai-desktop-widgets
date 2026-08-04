# AI Desktop Widgets

Usage widgets for [Übersicht](https://tracesof.net/uebersicht/) on macOS. Keep an eye on Claude Code, GitHub Copilot CLI, and Codex without leaving your desktop.

## Included widgets

- **Claude Code** — 24-hour activity, active block, plan quota, context use, and an optional status pet.
- **GitHub Copilot CLI** — today and month activity, AI units, and a monthly budget indicator.
- **Codex** — token activity, current context, subscription quota windows, and an API-rate-equivalent token estimate.

## Requirements

- macOS and Übersicht.
- Node.js and npm for the Claude Code and Codex widgets.
- The CLI and local session data for each widget you install:
  - Claude Code, signed in, for `claude`.
  - GitHub Copilot CLI, with `~/.copilot/session-store.db`, for `copilot`. macOS `sqlite3` is used to read it.
  - Codex CLI, signed in, for `codex`. A Codex version with `app-server` support provides the live quota windows; session logs remain the fallback.

## Install

Clone the repository, then run the installer from its root:

```sh
git clone https://github.com/TonPC64/ai-desktop-widgets.git
cd ai-desktop-widgets
bash scripts/install.sh --widgets all
```

The installer copies selected widgets to `~/Library/Application Support/Übersicht/widgets` and their runtime files to `~/.local/share/ai-desktop-widgets`. Start Übersicht and enable the widgets from its menu if they are not already visible.

## Widget selection

Install one widget, a comma-separated selection, or everything:

```sh
bash scripts/install.sh --widgets claude
bash scripts/install.sh --widgets copilot
bash scripts/install.sh --widgets codex
bash scripts/install.sh --widgets all
```

Run the same command again to change the selection. `--widgets claude,copilot` is also supported.

## Data and privacy

The collectors run locally and read only the local data needed to create aggregate usage displays. They do not upload session logs, prompts, or responses.

- Claude reads local `~/.claude` session data. To show plan quota, it also calls Anthropic's authenticated OAuth usage endpoint using your existing Claude credentials.
- Copilot reads `~/.copilot/session-store.db` locally and opens it read-only. If `COPILOT_BUDGET_ORG` is set, it optionally asks GitHub's budget API for that organization; `COPILOT_MONTHLY_AIU_LIMIT` avoids that lookup.
- Codex reads bounded local `~/.codex` session-log tails and invokes the local `codex app-server --stdio` for quota when available. It does not copy prompt or response content.

Caches are stored locally under `~/.cache` to avoid frequent reads and quota requests.

## Codex quota and pricing

The Codex widget gets quota windows from the local Codex app server when the installed CLI supports it. If that is unavailable, it can still show token activity from local session logs, but quota windows may be absent or stale.

Its dollar figure is an API-rate-equivalent estimate calculated from logged token counts and the listed model rates. It is **not** a Codex subscription charge, invoice, or guarantee: subscription allowances, included usage, discounts, model mappings, and actual billing can differ. Unknown models are left unpriced.

## Troubleshooting

- **No widget appears:** confirm Übersicht is running, then re-run the relevant `--widgets` command.
- **Empty data:** use the corresponding CLI once and verify its local data exists; the widget returns an empty state when it cannot find it.
- **Claude/Codex says Node is unavailable:** install Node.js and make it available to desktop applications, then reinstall that widget.
- **Codex quota is missing:** update/sign in to Codex CLI and confirm `codex app-server` is available; token activity can still work without it.
- **Copilot budget is wrong:** set `COPILOT_MONTHLY_AIU_LIMIT` to your monthly limit. For an organization lookup, set `COPILOT_BUDGET_ORG` and authenticate `gh` with the required billing permission.

## Uninstall

Run the uninstaller from the repository root:

```sh
bash scripts/uninstall.sh
```

It removes only this project's widget directories, runtime files, and LaunchAgent. Shared Claude hooks in `~/.claude/settings.json` and unrelated Übersicht widgets are intentionally preserved.

## Credits and license

Built with [Übersicht](https://tracesof.net/uebersicht/), [ccusage](https://github.com/ryoppippi/ccusage), Claude Code, GitHub Copilot CLI, and Codex CLI. Released under the [MIT License](LICENSE).
