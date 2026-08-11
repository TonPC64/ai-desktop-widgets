# Native AI Provider Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let one native WidgetKit widget select Copilot, Claude, or Codex from its configuration screen.

**Architecture:** The host runs the three existing local collectors once per refresh, decodes each source into a shared `AIProviderSnapshot`, and writes one JSON file per provider. The widget uses `AppIntentConfiguration` to select a provider and renders the selected normalized snapshot. Existing Copilot presentation remains compatible while Claude and Codex use their own quota/token values.

**Tech Stack:** Swift 6, SwiftUI, WidgetKit, AppIntents, Foundation, existing Bash/Node collectors.

## Global Constraints

- Keep one widget kind.
- Do not execute shell or Node from the widget extension.
- A failed provider refresh must not block other providers.
- Keep Copilot’s price toggle only for Copilot.
- No new dependencies.

---

### Task 1: Add normalized provider models and decoders

**Files:**
- Create: `native/ai-widgets/Sources/CopilotWidgetCore/AIProviderSnapshot.swift`
- Modify: `native/ai-widgets/AIWidgetsExtension.xcodeproj/project.pbxproj`
- Test: `native/ai-widgets/Tests/CopilotWidgetCoreTests/ProviderSnapshotTests.swift`

**Interfaces:**
- `AIProvider: String, Codable, CaseIterable, AppEnum, Sendable` with `.copilot`, `.claude`, `.codex` and display names.
- `AIProviderSnapshot: Codable, Equatable, Sendable` with provider, observedAt, title, heroText, detailText, progress, buckets, models, and `priceModeSupported`.
- `ProviderPayload.decode(provider:data:observedAt:) throws -> AIProviderSnapshot`.

- [ ] Write one failing test per source proving Copilot percentage, Claude quota, and Codex quota decode into the shared fields.
- [ ] Run `swift test --package-path native/ai-widgets`; confirm the new tests fail because the types are absent.
- [ ] Implement the smallest Codable models and decoders. Use Copilot’s existing `CollectorPayload` values, Claude `quota`/`month`/`bins`, and Codex `quota`/`monthTokens`/`bins`.
- [ ] Run the focused tests, then the full Swift test suite.
- [ ] Commit with `feat: normalize native AI provider snapshots`.

### Task 2: Store snapshots per provider

**Files:**
- Modify: `native/ai-widgets/Sources/CopilotWidgetCore/SnapshotStore.swift`
- Test: `native/ai-widgets/Tests/CopilotWidgetCoreTests/SnapshotStoreTests.swift`

**Interfaces:**
- `SnapshotStore.providerURL(provider:applicationSupportDirectory:) -> URL`.
- `SnapshotStore.save(_:provider:)` and `load(provider:)`.

- [ ] Add a failing test that saves and loads two providers without overwriting either file.
- [ ] Run that test and confirm it fails.
- [ ] Add provider filenames below `AIWidgets/` while retaining the existing Copilot path as a compatibility alias.
- [ ] Run store tests and the full Swift suite.
- [ ] Commit with `feat: store provider snapshots separately`.

### Task 3: Refresh all collectors from the native host

**Files:**
- Modify: `native/ai-widgets/Sources/CopilotWidgetHost/main.swift`
- Modify: `native/ai-widgets/scripts/build-app.sh`

**Interfaces:**
- Host collector map: `AIProvider` to bundled executable and decoder.
- Each provider refresh writes independently and reloads `CopilotWidgetPaths.widgetKind` once after the loop.

- [ ] Add the collector scripts under `Contents/Resources/scripts/` so their existing sibling-relative paths work: `copilot-data.sh`, `claude-status.sh`, `status.js`, `codex-data.sh`, and `codex-data.js`.
- [ ] Replace the single-provider refresh with a loop that runs each collector and catches errors per provider.
- [ ] Use `claude-status.sh graph` for Claude and existing `codex-data.sh` for Codex; never fail the whole refresh because one command is unavailable.
- [ ] Build the Swift package and app to catch host integration errors.
- [ ] Commit with `feat: refresh native snapshots for all providers`.

### Task 4: Add provider configuration and render normalized data

**Files:**
- Create: `native/ai-widgets/WidgetExtension/ProviderConfigurationIntent.swift`
- Modify: `native/ai-widgets/WidgetExtension/CopilotStatusWidget.swift`
- Modify: `native/ai-widgets/WidgetExtension/Info.plist`
- Modify: `native/ai-widgets/AIWidgetsExtension.xcodeproj/project.pbxproj`

**Interfaces:**
- `ProviderConfigurationIntent: WidgetConfigurationIntent` with `@Parameter(title: "AI provider") var provider: AIProvider`.
- `CopilotEntry` carries the selected `AIProvider` and optional `AIProviderSnapshot`.

- [ ] Add the intent and use `AppIntentConfiguration` with a default Copilot provider.
- [ ] Read the selected provider snapshot in the timeline provider.
- [ ] Render provider title, normalized hero/detail/progress, chart, and model legend; show the provider-specific unavailable state.
- [ ] Keep `TogglePriceModeIntent` only when the selected provider is Copilot.
- [ ] Build the widget extension and fix compile issues.
- [ ] Commit with `feat: add native AI provider widget configuration`.

### Task 5: Verify the complete native widget

**Files:**
- Modify: `README.md`

- [ ] Update native widget documentation from Copilot-only wording to provider selection.
- [ ] Run `swift test --package-path native/ai-widgets`.
- [ ] Run `bash native/ai-widgets/scripts/build-app.sh`.
- [ ] Run `bash native/ai-widgets/scripts/verify-app.sh native/ai-widgets/dist/'AI Widgets.app'`.
- [ ] Inspect `git diff --check` and commit with `docs: document native provider selection`.
