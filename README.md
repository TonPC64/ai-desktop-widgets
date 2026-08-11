# AI Desktop Widgets

Desktop widgets for monitoring AI CLI usage on macOS. Includes two flavors:

- **Übersicht widgets** — live overlays for Claude Code, GitHub Copilot CLI, Codex, and Antigravity CLI running on your desktop.
- **Native WidgetKit app** (macOS 15+) — a standard macOS widget for Claude, Copilot, and Codex that lives in Notification Center or on the desktop, with no Dock icon or menu bar.

<img width="1285" height="391" alt="widgets" src="https://github.com/user-attachments/assets/b8e3d15b-4537-406a-9a70-940c1bf057b7" />

## Included widgets

- **Claude Code** — 24-hour activity, active block, plan quota, context use, and an optional status pet.
- **GitHub Copilot CLI** — today and month activity, AI units, and a monthly budget indicator.
- **Codex** — token activity, current context, subscription quota windows, and an API-rate-equivalent token estimate.
- **Antigravity CLI** — 24h prompt activity bars, model in use, session stats, and last prompt preview.

## Requirements

- macOS and [Übersicht](https://tracesof.net/uebersicht/).
- Node.js and npm for the Claude Code and Codex widgets.
- The CLI and local session data for each widget you install:
  - Claude Code, signed in, for `claude`.
  - GitHub Copilot CLI, with `~/.copilot/session-store.db`, for `copilot`. macOS `sqlite3` is used to read it.
  - Codex CLI, signed in, for `codex`. A Codex version with `app-server` support provides the live quota windows; session logs remain the fallback.
  - Antigravity CLI (`agy`), signed in, for `agy`. Reads `~/.gemini/antigravity-cli` local data only.

## Install

Clone the repository, then run the installer from its root:

```sh
git clone https://github.com/TonPC64/ai-desktop-widgets.git
cd ai-desktop-widgets
bash scripts/install.sh --widgets all
```

The installer copies selected widgets to `~/Library/Application Support/Übersicht/widgets` and their runtime files to `~/.local/share/ai-desktop-widgets`. Start Übersicht and enable the widgets from its menu if they are not already visible.

## Native AI Widgets (macOS 15+)

The native **AI Widgets** app is a WidgetKit alternative to Übersicht. It has no Dock icon or menu bar, reads the same local data as the Übersicht widgets, and refreshes every five minutes.

### Sizes and providers

The widget comes in **Small**, **Medium**, and **Large** WidgetKit sizes. After installing, add **AI Status** from the macOS Widget Gallery and choose a provider in the widget configuration screen:

| Provider | What it shows |
|----------|---------------|
| **Claude** | 24h / 7-day / monthly token spend, model color bars, 7-day quota percentage, monthly token total. Tap the widget to cycle through time periods. |
| **Copilot** | Monthly AIU percentage with a progress ring, today's AIU / token / request counts. Tap to toggle between the quota percentage view and an estimated dollar value (not a GitHub billing total). |
| **Codex** | Today's cost estimate, monthly spend, context-window fill, and subscription quota bars. Tap to cycle between today / 7-day / monthly usage windows. |

### Requirements

- macOS 15 or later
- Full Xcode (installed and license accepted)
- The same CLI data as the Übersicht counterpart (signed-in `claude`, `gh copilot`, or `codex`)

### Install

```sh
bash native/ai-widgets/scripts/install-local-widget.sh
```

The script builds the app, copies it to `~/Applications/AI Widgets.app`, registers the widget extension with WidgetKit, and launches the background helper (`CopilotWidgetHost`) that runs the read-only collectors once per minute. It does not install or modify any Codex hooks.

After the script completes, open the macOS Widget Gallery (long-press the desktop or open Notification Center), search for **AI Status**, and add it. Use the widget's configuration screen to select the provider.

## Widget selection

Install one widget, a comma-separated selection, or everything:

```sh
bash scripts/install.sh --widgets claude
bash scripts/install.sh --widgets copilot
bash scripts/install.sh --widgets codex
bash scripts/install.sh --widgets agy
bash scripts/install.sh --widgets all
```

Run additional commands to install more widgets; existing widgets and runtime files are preserved. `--widgets claude,copilot,agy` is also supported.

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

It removes this project's widget directories, runtime files, LaunchAgent, and Claude hooks. Unrelated Claude hooks in `~/.claude/settings.json` and unrelated Übersicht widgets are preserved.

## Inspiration

This project is inspired by [korrio/claude-status-touch-bar](https://github.com/korrio/claude-status-touch-bar) — a Touch Bar + SwiftBar + Übersicht widget that shows live Claude Code usage on MacBook Pro Touch Bars. The widget layout (5H / 7D quota bars, 24-hour activity chart, tamaclaude desk pet, and per-model color coding) originates from that project.

> **After cloning this repo**, run the installer as noted in the [Install](#install) section. No Xcode build or Touch Bar hardware is needed — this fork targets the Übersicht desktop widget only.

## Credits and license

Built with [Übersicht](https://tracesof.net/uebersicht/), [ccusage](https://github.com/ryoppippi/ccusage), Claude Code, GitHub Copilot CLI, and Codex CLI. Inspired by [korrio/claude-status-touch-bar](https://github.com/korrio/claude-status-touch-bar) (MIT, © korrio). Released under the [MIT License](LICENSE).
