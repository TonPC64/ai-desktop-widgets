# Native AI Provider Widget

## Goal

Allow one native macOS widget to display Copilot, Claude, or Codex usage, selected from the widget configuration screen.

## Design

- Replace the static WidgetKit configuration with an `AppIntentConfiguration`.
- Expose a single provider choice: Copilot, Claude, or Codex.
- Keep one widget kind and reload its timeline after collector refreshes.
- Run the existing local collectors from the native host and normalize their incompatible JSON into a small shared presentation snapshot.
- Store one normalized snapshot per provider so a configured widget can read the selected provider without executing shell commands in the extension.
- Render the selected provider name, its primary usage value, supporting quota/token detail, and available chart data.
- Keep Copilot’s percentage/estimated-value toggle only for Copilot. Claude and Codex retain their native quota/token semantics.
- If the selected provider has no usable data, show the provider name and the existing unavailable state.

## Data flow

```text
existing collectors -> native host -> provider snapshots -> WidgetKit timeline -> configured provider view
```

The host refreshes all three providers on its existing one-minute timer. A failure for one collector does not prevent other provider snapshots from being updated.

## Scope

Included: provider selection, collector integration, normalized snapshots, provider-specific display values, and focused tests for configuration/data normalization.

Excluded: tap-to-cycle behavior, new collectors, changes to the Übersicht widgets, and provider-specific settings beyond the picker.

## Verification

- Run the Swift package test suite.
- Build the native app/widget and run its existing verification script.
- Confirm the provider intent compiles and the selected provider reaches the rendered entry.
