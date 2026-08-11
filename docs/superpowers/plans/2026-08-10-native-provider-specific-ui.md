# Native Provider-Specific UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the native widget display provider-specific metrics for Copilot, Claude, and Codex instead of the Copilot layout for every selection.

**Architecture:** Extend the normalized provider snapshot with compact metric and quota rows decoded from each existing collector. Keep one SwiftUI glass shell and shared 24-hour chart, but branch the summary section by provider.

**Tech Stack:** Swift 6, SwiftUI, WidgetKit, Foundation.

## Global Constraints

- Provider selection remains configuration-screen based.
- Keep the existing glass treatment and shared chart.
- Do not add tamaclaude or any pet UI to the native widget.
- Do not change the Übersicht widgets or collectors.
- No new dependencies.

---

### Task 1: Normalize provider-specific metrics

**Files:**
- Modify: `native/ai-widgets/Sources/CopilotWidgetCore/AIProviderSnapshot.swift`
- Test: `native/ai-widgets/Tests/CopilotWidgetCoreTests/ProviderSnapshotTests.swift`

**Interfaces:**
- `ProviderMetric(label: String, value: String)`.
- `ProviderQuota(label: String, usedPercent: Double, detail: String?)`.
- `AIProviderSnapshot.metrics` and `.quotas`.

- [ ] Add failing assertions for Copilot AIU/tokens, Claude 5H/7D quota, and Codex month cost/context/quota.
- [ ] Run `swift test --package-path native/ai-widgets --filter ProviderSnapshotTests` and confirm failure.
- [ ] Decode those fields from the existing normalized payloads.
- [ ] Run the focused test and full Swift suite.

### Task 2: Render provider-specific native cards

**Files:**
- Modify: `native/ai-widgets/WidgetExtension/CopilotStatusWidget.swift`

- [ ] Replace the generic summary rows with provider branches:
  - Copilot: month AIU hero, budget detail, progress, today metrics.
  - Claude: 5H quota hero, 7D/active-block metrics, reset details.
  - Codex: month cost/token hero, context metric, quota windows.
- [ ] Keep the shared model chart and legend below each provider summary.
- [ ] Ensure the native card contains no pet/tamaclaude elements.
- [ ] Build the widget extension with `bash native/ai-widgets/scripts/build-app.sh`.

### Task 3: Verify and install

**Files:**
- Modify: `README.md` only if displayed labels or setup instructions change.

- [ ] Run `swift test --package-path native/ai-widgets`.
- [ ] Run `bash native/ai-widgets/scripts/build-app.sh`.
- [ ] Run `bash native/ai-widgets/scripts/verify-app.sh "native/ai-widgets/dist/AI Widgets.app"`.
- [ ] Run `bash native/ai-widgets/scripts/install-local-widget.sh`.
- [ ] Run `git diff --check`.
