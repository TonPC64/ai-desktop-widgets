# Native Claude Window Cycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the native Claude widget cycle truthful, period-specific cost/token dashboards and graphs for 5H, 7D, and this month, with Übersicht model colors.

**Architecture:** Extend the existing Claude collector payload with three local usage windows built from one pass over session events. Normalize those windows into the existing provider snapshot, then let one Claude AppIntent select a window and reload the existing WidgetKit timeline. Keep quota percentages conditional on real OAuth quota data and use cost/tokens for Bedrock.

**Tech Stack:** Node.js standard library, Swift 6, AppIntents, WidgetKit, SwiftUI, XCTest.

## Global Constraints

- Bedrock or missing quota data must never render a synthetic `0%` quota.
- Cycle order is exactly `5H → 7D → This month → 5H`.
- Headline, detail, and graph always use the same selected period.
- Claude colors are Fable `#3987E5`, Opus `#199E70`, Sonnet `#C98500`, Haiku `#E66767`, other `#898781`.
- Copilot, Codex, and Übersicht behavior remain unchanged.
- Add no dependencies.

---

### Task 1: Collect Claude Usage Windows

**Files:**
- Create: `scripts/claude-usage-windows.js`
- Create: `scripts/claude-usage-windows.test.js`
- Modify: `scripts/status.js:369-455`

**Interfaces:**
- Consumes: token events shaped as `{ timestamp: number, model: string, tokens: number }`.
- Produces: `buildUsageWindows(events, now, monthStart)` returning `fiveHour`, `sevenDay`, and `month`, each with `start`, `end`, `bucketMs`, and `bins`.

- [ ] **Step 1: Write the failing aggregation test**

```js
const assert = require('node:assert/strict');
const { buildUsageWindows } = require('./claude-usage-windows');

const hour = 60 * 60 * 1000;
const now = Date.UTC(2026, 7, 10, 12);
const monthStart = Date.UTC(2026, 7, 1);
const windows = buildUsageWindows([
  { timestamp: now - hour, model: 'opus-4-8', tokens: 100 },
  { timestamp: now - 6 * hour, model: 'sonnet-4-6', tokens: 200 },
  { timestamp: now - 8 * 24 * hour, model: 'haiku-4-5', tokens: 300 },
], now, monthStart);

assert.equal(windows.fiveHour.bins.flatMap((b) => Object.keys(b.models)).includes('opus-4-8'), true);
assert.equal(windows.fiveHour.bins.flatMap((b) => Object.keys(b.models)).includes('sonnet-4-6'), false);
assert.equal(windows.sevenDay.bins.flatMap((b) => Object.keys(b.models)).includes('sonnet-4-6'), true);
assert.equal(windows.month.bins.flatMap((b) => Object.keys(b.models)).includes('haiku-4-5'), true);
```

- [ ] **Step 2: Run the test and verify RED**

Run: `node scripts/claude-usage-windows.test.js`

Expected: FAIL because `./claude-usage-windows` does not exist.

- [ ] **Step 3: Implement fixed-size period aggregation**

```js
function makeWindow(events, start, end, bucketMs) {
  const bins = Array.from({ length: Math.ceil((end - start) / bucketMs) }, (_, i) => ({
    t: start + i * bucketMs,
    models: {},
  }));
  for (const event of events) {
    if (event.timestamp < start || event.timestamp >= end) continue;
    const bin = bins[Math.floor((event.timestamp - start) / bucketMs)];
    bin.models[event.model] = (bin.models[event.model] || 0) + event.tokens;
  }
  return { start, end, bucketMs, bins };
}

function buildUsageWindows(events, now, monthStart) {
  const hour = 60 * 60 * 1000;
  return {
    fiveHour: makeWindow(events, now - 5 * hour, now, 10 * 60 * 1000),
    sevenDay: makeWindow(events, now - 7 * 24 * hour, now, 4 * hour),
    month: makeWindow(events, monthStart, now, 24 * hour),
  };
}

module.exports = { buildUsageWindows };
```

In `status.js`, require `buildUsageWindows`, collect token events from `monthStart` instead of only the last 24 hours, retain the existing deduplication key, and attach totals:

```js
const windows = buildUsageWindows(events, now, monthStart.getTime());
Object.assign(windows.fiveHour, { cost: block && block.costUSD, tokens: block && block.totalTokens });
Object.assign(windows.sevenDay, { cost: totals && totals.totalCost, tokens: totals && totals.totalTokens });
Object.assign(windows.month, { cost: monthTotals && monthTotals.totalCost, tokens: monthTotals && monthTotals.totalTokens });
```

Emit `usageWindows: windows` beside the existing payload fields. Keep the current `bins`, `block`, `week`, and `month` keys for Übersicht compatibility.

- [ ] **Step 4: Run the collector checks and verify GREEN**

Run:

```bash
node scripts/claude-usage-windows.test.js
bash scripts/claude-status.sh graph | jq -e '.usageWindows.fiveHour and .usageWindows.sevenDay and .usageWindows.month'
```

Expected: both commands exit 0; all three windows contain domain metadata and bins.

- [ ] **Step 5: Commit the collector change**

```bash
git add scripts/claude-usage-windows.js scripts/claude-usage-windows.test.js scripts/status.js
git commit -m "feat: collect Claude usage windows"
```

---

### Task 2: Normalize Truthful Claude Window Presentation

**Files:**
- Modify: `native/ai-widgets/Sources/CopilotWidgetCore/AIProviderSnapshot.swift`
- Modify: `native/ai-widgets/Tests/CopilotWidgetCoreTests/ProviderSnapshotTests.swift`

**Interfaces:**
- Consumes: collector `usageWindows` and optional OAuth `quota`.
- Produces: `ClaudeUsagePeriod`, `ClaudeUsageWindow`, `AIProviderSnapshot.claudeWindows`, and `claudeWindow(for:)`.

- [ ] **Step 1: Write failing snapshot and cycle tests**

Add a Bedrock-style fixture with `quota: null` and all three windows. Assert:

```swift
XCTAssertEqual(snapshot.quotas, [])
XCTAssertEqual(snapshot.claudeWindow(for: .fiveHour)?.heroText, "$1.16")
XCTAssertEqual(snapshot.claudeWindow(for: .fiveHour)?.detailText, "3.4M tokens · 5H usage")
XCTAssertEqual(snapshot.claudeWindow(for: .sevenDay)?.heroText, "$126")
XCTAssertEqual(ClaudeUsagePeriod.fiveHour.next, .sevenDay)
XCTAssertEqual(ClaudeUsagePeriod.sevenDay.next, .month)
XCTAssertEqual(ClaudeUsagePeriod.month.next, .fiveHour)
```

Retain the existing OAuth fixture and assert real `25%` and `40%` values remain available for 5H and 7D.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `swift test --package-path native/ai-widgets --filter ProviderSnapshotTests`

Expected: FAIL because the Claude period/window interfaces do not exist and missing quota still creates zero-valued rows.

- [ ] **Step 3: Add the minimal Claude period/window model**

```swift
public enum ClaudeUsagePeriod: String, Codable, CaseIterable, Sendable {
    case fiveHour, sevenDay, month

    public var next: Self {
        switch self {
        case .fiveHour: .sevenDay
        case .sevenDay: .month
        case .month: .fiveHour
        }
    }
}

public struct ClaudeUsageWindow: Codable, Equatable, Sendable {
    public let period: ClaudeUsagePeriod
    public let heroText: String
    public let detailText: String
    public let buckets: [UsageBucket]
    public let models: [String]
    public let chartStart: Date
    public let chartInterval: TimeInterval
    public let chartSlotCount: Int
}
```

Add optional `claudeWindows: [ClaudeUsageWindow]?` to `AIProviderSnapshot` with a default of `nil`, and:

```swift
public func claudeWindow(for period: ClaudeUsagePeriod) -> ClaudeUsageWindow? {
    claudeWindows?.first { $0.period == period }
}
```

Decode each collector window. For 5H/7D, use a real quota percentage only when its window exists; otherwise format local cost with the existing dollar rules. Build `quotas` only when `payload.quota != nil`, so missing quota produces no `0%` rows.

- [ ] **Step 4: Run all Swift tests and verify GREEN**

Run: `swift test --package-path native/ai-widgets`

Expected: all tests pass with zero failures.

- [ ] **Step 5: Commit the normalized model**

```bash
git add native/ai-widgets/Sources/CopilotWidgetCore/AIProviderSnapshot.swift native/ai-widgets/Tests/CopilotWidgetCoreTests/ProviderSnapshotTests.swift
git commit -m "feat: present Claude usage by window"
```

---

### Task 3: Cycle Native Claude UI and Match Übersicht Colors

**Files:**
- Modify: `native/ai-widgets/WidgetExtension/TogglePriceModeIntent.swift`
- Modify: `native/ai-widgets/WidgetExtension/CopilotStatusWidget.swift`
- Modify: `native/ai-widgets/WidgetExtension/UsageChartView.swift`
- Modify: `native/ai-widgets/Sources/CopilotWidgetCore/AIProviderSnapshot.swift`
- Modify: `native/ai-widgets/Tests/CopilotWidgetCoreTests/ProviderSnapshotTests.swift`

**Interfaces:**
- Consumes: `ClaudeUsagePeriod` and `ClaudeUsageWindow` from Task 2.
- Produces: `CycleClaudeUsagePeriodIntent`, period-aware timeline entries, chart domains, and stable Claude family color tokens.

- [ ] **Step 1: Write the failing palette test**

```swift
XCTAssertEqual(ClaudeModelPalette.hex(for: "claude-opus-4-8"), 0x199E70)
XCTAssertEqual(ClaudeModelPalette.hex(for: "sonnet-4-6"), 0xC98500)
XCTAssertEqual(ClaudeModelPalette.hex(for: "haiku-4-5"), 0xE66767)
XCTAssertEqual(ClaudeModelPalette.hex(for: "fable-1"), 0x3987E5)
XCTAssertEqual(ClaudeModelPalette.hex(for: "unknown"), 0x898781)
```

- [ ] **Step 2: Run the palette test and verify RED**

Run: `swift test --package-path native/ai-widgets --filter ProviderSnapshotTests`

Expected: FAIL because `ClaudeModelPalette` does not exist.

- [ ] **Step 3: Add provider-independent Claude color tokens**

```swift
public enum ClaudeModelPalette {
    public static func hex(for model: String) -> UInt32 {
        let name = model.lowercased().replacingOccurrences(of: "claude-", with: "")
        if name.hasPrefix("fable") { return 0x3987E5 }
        if name.hasPrefix("opus") { return 0x199E70 }
        if name.hasPrefix("sonnet") { return 0xC98500 }
        if name.hasPrefix("haiku") { return 0xE66767 }
        return 0x898781
    }
}
```

- [ ] **Step 4: Add the Claude cycle intent**

Append to `TogglePriceModeIntent.swift`:

```swift
struct CycleClaudeUsagePeriodIntent: AppIntent {
    static let title: LocalizedStringResource = "Change Claude usage period"
    static let key = "claude.widget.usage-period"

    func perform() async throws -> some IntentResult {
        let current = ClaudeUsagePeriod(rawValue: UserDefaults.standard.string(forKey: Self.key) ?? "") ?? .fiveHour
        UserDefaults.standard.set(current.next.rawValue, forKey: Self.key)
        WidgetCenter.shared.reloadTimelines(ofKind: CopilotWidgetPaths.widgetKind)
        return .result()
    }
}
```

- [ ] **Step 5: Make timeline and view period-aware**

Add `claudePeriod: ClaudeUsagePeriod` to `CopilotEntry`, read it from `CycleClaudeUsagePeriodIntent.key`, and use `snapshot.claudeWindow(for: entry.claudePeriod)` for Claude headline, detail, buckets, models, and chart domain. Wrap the Claude headline in `Button(intent: CycleClaudeUsagePeriodIntent())`; keep the existing Copilot price button unchanged.

Pass `snapshot.provider` and the selected domain into `UsageChartView`. Build slots from `chartStart`, `chartInterval`, and `chartSlotCount` when supplied; preserve the existing 24-hour/30-minute default for Copilot and Codex.

Convert Claude hex tokens to SwiftUI colors locally:

```swift
let hex = ClaudeModelPalette.hex(for: model)
return Color(
    red: Double((hex >> 16) & 0xff) / 255,
    green: Double((hex >> 8) & 0xff) / 255,
    blue: Double(hex & 0xff) / 255
)
```

Use this mapping in both chart bars and legend dots only when provider is `.claude`.

- [ ] **Step 6: Build and run all tests**

Run:

```bash
swift test --package-path native/ai-widgets
COPILOT_WIDGET_OUTPUT="$(mktemp -d)/AI Widgets.appex" bash native/ai-widgets/scripts/build-widget-extension.sh
```

Expected: all tests pass and the extension build/sign verification exits 0.

- [ ] **Step 7: Commit the native interaction**

```bash
git add native/ai-widgets/WidgetExtension/TogglePriceModeIntent.swift native/ai-widgets/WidgetExtension/CopilotStatusWidget.swift native/ai-widgets/WidgetExtension/UsageChartView.swift native/ai-widgets/Sources/CopilotWidgetCore/AIProviderSnapshot.swift native/ai-widgets/Tests/CopilotWidgetCoreTests/ProviderSnapshotTests.swift
git commit -m "feat: cycle native Claude usage windows"
```

---

### Task 4: Fresh Install and Live Verification

**Files:**
- Verify: `native/ai-widgets/dist/AI Widgets.app`
- Install: `$HOME/Applications/AI Widgets.app`

**Interfaces:**
- Consumes: completed collector, normalized snapshot, and widget UI.
- Produces: one registered, signed native widget installation.

- [ ] **Step 1: Run final repository checks**

```bash
node scripts/claude-usage-windows.test.js
swift test --package-path native/ai-widgets
git diff --check
```

Expected: every command exits 0.

- [ ] **Step 2: Use the fresh-install workflow**

Use `$fresh-install-native-widget`. Unregister the current extension before moving the old generated app to Trash, then run `native/ai-widgets/scripts/install-local-widget.sh`. If a command reports HTTP 429, wait 60 seconds and retry only that command.

- [ ] **Step 3: Verify live Claude data**

After selecting Claude, verify:

```bash
jq -e '.claudeWindows | length == 3' "$HOME/Library/Containers/com.ai-desktop-widgets.ai-widgets.widget/Data/Library/Application Support/AIWidgets/claude.json"
/usr/bin/log show --last 5m --style compact --predicate 'subsystem == "com.ai-desktop-widgets.ai-widgets.widget" AND category == "timeline"' | rg 'provider=claude snapshot=claude'
```

Expected: three Claude windows and a matching WidgetKit timeline log. Manually click the headline three times and confirm labels, cost/tokens, and graph cycle `5H → 7D → This month → 5H` with Opus green and Sonnet amber.
