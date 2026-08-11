# Native Claude Today and Spend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Claude's 5H native-widget period with Today and show period-matched spend whenever a real quota percentage is unavailable.

**Architecture:** Build three local-calendar windows in the existing Claude collector and attach ccusage daily costs computed from the same boundaries. Decode those windows into the existing native presentation model, migrate saved `fiveHour` state to `today`, and keep the current AppIntent-driven cycle and chart rendering. Bundle the existing ccusage dependency so spend fallback also works in the standalone installed app.

**Tech Stack:** Node.js standard library, ccusage (existing dependency), Swift 6, AppIntents, WidgetKit, XCTest.

## Global Constraints

- Claude cycle is exactly `Today → 7D → This month → Today`.
- Today is local midnight through now; 7D is local midnight six days ago through now; This month is local month start through now.
- Headline, token detail, graph, graph domain, label, and spend use the same period.
- Use a real matching OAuth percentage when available; otherwise use matching-period spend.
- Missing spend renders `--`, never `$0` or `0%`.
- Existing saved `fiveHour` state migrates to Today.
- Legacy Übersicht keys `bins`, `block`, `week`, and `month` remain unchanged.
- Copilot, Codex, provider selection, and Claude colors remain unchanged.
- Add no dependencies.
- If a command reports HTTP 429 or `Too Many Requests`, wait 60 seconds and retry only that command.

---

### Task 1: Collect Calendar Windows and Matching Spend

**Files:**
- Modify: `scripts/claude-usage-windows.js`
- Modify: `scripts/claude-usage-windows.test.js`
- Modify: `scripts/status.js`

**Interfaces:**
- Consumes: token events plus explicit local starts and optional costs.
- Produces: `buildUsageWindows(events, now, starts, costs)` with `today`, `sevenDay`, and `month`; `usageScanStart(starts)`.

- [ ] **Step 1: Write failing calendar-domain and cost tests**

Replace five-hour expectations and add this focused case in `scripts/claude-usage-windows.test.js`:

```js
test('builds Today, 7D, and month with matching calendar costs', () => {
  const now = Date.UTC(2026, 7, 10, 12);
  const starts = {
    today: Date.UTC(2026, 7, 10),
    sevenDay: Date.UTC(2026, 7, 4),
    month: Date.UTC(2026, 7, 1),
  };
  const windows = buildUsageWindows([
    { timestamp: now - hour, model: 'today', tokens: 10 },
    { timestamp: starts.today - hour, model: 'week', tokens: 20 },
    { timestamp: starts.sevenDay - hour, model: 'month', tokens: 30 },
  ], now, starts, { today: 1.25, sevenDay: 12.5, month: 25 });

  assert.equal(windows.today.tokens, 10);
  assert.equal(windows.sevenDay.tokens, 30);
  assert.equal(windows.month.tokens, 60);
  assert.deepEqual(
    [windows.today.cost, windows.sevenDay.cost, windows.month.cost],
    [1.25, 12.5, 25]
  );
  assert.equal(windows.fiveHour, undefined);
  assert.equal(usageScanStart(starts), starts.month);
});
```

Update the standalone graph assertion to require `usageWindows.today`, `sevenDay`, and `month`.

- [ ] **Step 2: Run the Node test and verify RED**

Run: `node scripts/claude-usage-windows.test.js`

Expected: FAIL because `buildUsageWindows` still emits `fiveHour`, accepts old positional starts, and does not retain supplied costs.

- [ ] **Step 3: Implement the minimum calendar-window helper**

Use the existing `makeWindow` loop and change only its inputs/output:

```js
function makeWindow(events, start, end, bucketMs, cost = null) {
  const bins = Array.from({ length: Math.ceil((end - start) / bucketMs) }, (_, i) => ({
    t: start + i * bucketMs,
    models: {},
  }));
  let tokens = 0;
  for (const event of events) {
    if (event.timestamp < start || event.timestamp >= end) continue;
    const bin = bins[Math.floor((event.timestamp - start) / bucketMs)];
    bin.models[event.model] = (bin.models[event.model] || 0) + event.tokens;
    tokens += event.tokens;
  }
  return { start, end, bucketMs, cost, tokens, bins };
}

function buildUsageWindows(events, now, starts, costs = {}) {
  return {
    today: makeWindow(events, starts.today, now, 30 * 60 * 1000, costs.today ?? null),
    sevenDay: makeWindow(events, starts.sevenDay, now, 4 * 60 * 60 * 1000, costs.sevenDay ?? null),
    month: makeWindow(events, starts.month, now, 24 * 60 * 60 * 1000, costs.month ?? null),
  };
}

function usageScanStart(starts) {
  return Math.min(starts.sevenDay, starts.month);
}
```

- [ ] **Step 4: Align `status.js` event and cost boundaries**

In graph mode, derive local starts once:

```js
const todayStart = new Date(nowDate.getFullYear(), nowDate.getMonth(), nowDate.getDate());
const sevenDayStart = new Date(nowDate.getFullYear(), nowDate.getMonth(), nowDate.getDate() - 6);
const monthStart = new Date(nowDate.getFullYear(), nowDate.getMonth(), 1);
const starts = {
  today: todayStart.getTime(),
  sevenDay: sevenDayStart.getTime(),
  month: monthStart.getTime(),
};
const scanStart = usageScanStart(starts);
```

Reuse the current ccusage wrapper with one local helper:

```js
function dailyTotalsSince(date) {
  const ymd = date.getFullYear() * 10000 + (date.getMonth() + 1) * 100 + date.getDate();
  try { return ccusage(['daily', '--since', String(ymd)]).totals || null; }
  catch { return null; }
}

const todayTotals = dailyTotalsSince(todayStart);
const totals = dailyTotalsSince(sevenDayStart);
const monthTotals = dailyTotalsSince(monthStart);
const windows = buildUsageWindows(events, now, starts, {
  today: todayTotals?.totalCost,
  sevenDay: totals?.totalCost,
  month: monthTotals?.totalCost,
});
```

Keep legacy `block`, `week`, and `month` serialization unchanged.

- [ ] **Step 5: Run collector GREEN checks**

Run:

```bash
node scripts/claude-usage-windows.test.js
node scripts/status.js graph | jq -e '.usageWindows.today and .usageWindows.sevenDay and .usageWindows.month and (has("bins") and has("block") and has("week") and has("month"))'
```

Expected: Node tests pass and jq prints `true`.

- [ ] **Step 6: Commit collector changes**

```bash
git add scripts/claude-usage-windows.js scripts/claude-usage-windows.test.js scripts/status.js
git commit -m "feat: collect Claude calendar spend windows"
```

---

### Task 2: Present Today and Spend in the Native Widget

**Files:**
- Modify: `native/ai-widgets/Sources/CopilotWidgetCore/AIProviderSnapshot.swift`
- Modify: `native/ai-widgets/Tests/CopilotWidgetCoreTests/ProviderSnapshotTests.swift`
- Modify: `native/ai-widgets/WidgetExtension/TogglePriceModeIntent.swift`
- Modify: `native/ai-widgets/WidgetExtension/CopilotStatusWidget.swift`

**Interfaces:**
- Consumes: collector `usageWindows.today`, `sevenDay`, and `month` plus optional OAuth `sevenDay` quota.
- Produces: `ClaudeUsagePeriod.today`, `ClaudeUsagePeriod.fromStoredValue(_:)`, and the existing `claudePresentation(for:)` API.

- [ ] **Step 1: Write failing native period, migration, and fallback tests**

Update Claude JSON fixtures to use `today`. Add these assertions:

```swift
func testClaudeUsagePeriodsCycleAndMigrateFiveHour() {
    XCTAssertEqual(ClaudeUsagePeriod.today.next, .sevenDay)
    XCTAssertEqual(ClaudeUsagePeriod.sevenDay.next, .month)
    XCTAssertEqual(ClaudeUsagePeriod.month.next, .today)
    XCTAssertEqual(ClaudeUsagePeriod.fromStoredValue("fiveHour"), .today)
    XCTAssertEqual(ClaudeUsagePeriod.fromStoredValue("sevenDay"), .sevenDay)
    XCTAssertEqual(ClaudeUsagePeriod.fromStoredValue(nil), .today)
}

func testClaudeUsesSpendWhenMatchingQuotaIsUnavailable() throws {
    let snapshot = try ProviderPayload.decode(
        provider: .claude,
        data: Data(#"{"bins":[],"quota":{"fiveHour":{"pct":25},"sevenDay":{"pct":40}},"usageWindows":{"today":{"start":1722729600000,"end":1722780000000,"bucketMs":1800000,"cost":1.16,"tokens":3400000,"bins":[]},"sevenDay":{"start":1722211200000,"end":1722780000000,"bucketMs":14400000,"cost":126,"tokens":99000000,"bins":[]},"month":{"start":1722470400000,"end":1722780000000,"bucketMs":86400000,"cost":248.5,"tokens":175000000,"bins":[]}}}"#.utf8),
        observedAt: date
    )

    XCTAssertEqual(snapshot.claudeWindow(for: .today)?.heroText, "$1.16")
    XCTAssertEqual(snapshot.claudeWindow(for: .sevenDay)?.heroText, "40%")
    XCTAssertEqual(snapshot.claudeWindow(for: .month)?.heroText, "$248.50")
    XCTAssertEqual(snapshot.claudeWindow(for: .today)?.detailText, "3.4M tokens · Today usage")
}
```

Retain the null-cost fixture and change it to assert Today renders `--` rather than `$0`.

- [ ] **Step 2: Run focused Swift tests and verify RED**

Run: `swift test --package-path native/ai-widgets --filter ProviderSnapshotTests`

Expected: FAIL because `.today`, `fromStoredValue(_:)`, and the `today` payload field do not exist.

- [ ] **Step 3: Implement the minimal native period model**

Replace the period enum behavior with:

```swift
public enum ClaudeUsagePeriod: String, Codable, CaseIterable, Sendable {
    case today, sevenDay, month

    public static func fromStoredValue(_ rawValue: String?) -> Self {
        if rawValue == "fiveHour" { return .today }
        return rawValue.flatMap(Self.init(rawValue:)) ?? .today
    }

    public var next: Self {
        switch self {
        case .today: .sevenDay
        case .sevenDay: .month
        case .month: .today
        }
    }

    public var headerLabel: String {
        switch self {
        case .today: "today"
        case .sevenDay: "last 7d"
        case .month: "this month"
        }
    }

    var usageLabel: String {
        switch self {
        case .today: "Today"
        case .sevenDay: "7D"
        case .month: "Month"
        }
    }
}
```

Decode `ClaudeUsageWindowsPayload.today`, map Today with no quota, map 7D with `quota.sevenDay`, and map month with no quota. Ignore the unrelated 5H OAuth quota so it never labels Today.

- [ ] **Step 4: Migrate both saved-state readers**

In `TogglePriceModeIntent.swift` and `CopilotStatusWidget.swift`, replace direct raw-value initialization with:

```swift
ClaudeUsagePeriod.fromStoredValue(
    UserDefaults.standard.string(forKey: CycleClaudeUsagePeriodIntent.key)
)
```

The intent still stores `current.next.rawValue` and reloads the same WidgetKit kind.

- [ ] **Step 5: Run native GREEN checks**

Run:

```bash
swift test --package-path native/ai-widgets
COPILOT_WIDGET_OUTPUT="$(mktemp -d)/AI Widgets.appex" bash native/ai-widgets/scripts/build-widget-extension.sh
git diff --check
```

Expected: all Swift tests pass, extension build/sign verification exits 0, and diff check is clean.

- [ ] **Step 6: Commit native changes**

```bash
git add native/ai-widgets/Sources/CopilotWidgetCore/AIProviderSnapshot.swift native/ai-widgets/Tests/CopilotWidgetCoreTests/ProviderSnapshotTests.swift native/ai-widgets/WidgetExtension/TogglePriceModeIntent.swift native/ai-widgets/WidgetExtension/CopilotStatusWidget.swift
git commit -m "feat: show Claude today and spend"
```

---

### Task 3: Bundle Spend Data and Fresh-Install

**Files:**
- Modify: `native/ai-widgets/scripts/build-app.sh`
- Modify: `native/ai-widgets/scripts/verify-app.sh`
- Install: `$HOME/Applications/AI Widgets.app`

**Interfaces:**
- Consumes: root `node_modules` installed from the committed lockfile.
- Produces: a standalone app whose Claude collector can execute ccusage and emit period spend.

- [ ] **Step 1: Add the failing app verification**

Add to `verify-app.sh`:

```bash
test -x "$app/Contents/Resources/node_modules/.bin/ccusage"
```

- [ ] **Step 2: Verify RED on the current app build**

Run: `bash native/ai-widgets/scripts/build-app.sh`

Expected: FAIL in `verify-app.sh` because the app does not bundle ccusage.

- [ ] **Step 3: Install locked dependencies and bundle them**

Run: `npm install`.

In `build-app.sh`, fail clearly if the dependency is absent and copy the existing dependency tree:

```bash
test -x "$PROJECT_ROOT/node_modules/.bin/ccusage"
ditto --norsrc "$PROJECT_ROOT/node_modules" "$APP/Contents/Resources/node_modules"
```

No package manifest changes are expected.

- [ ] **Step 4: Verify the standalone build GREEN**

Run:

```bash
bash native/ai-widgets/scripts/build-app.sh
bash native/ai-widgets/scripts/verify-app.sh "native/ai-widgets/dist/AI Widgets.app"
```

Expected: build and signature checks exit 0 and bundled ccusage is executable.

- [ ] **Step 5: Commit packaging changes**

```bash
git add native/ai-widgets/scripts/build-app.sh native/ai-widgets/scripts/verify-app.sh
git commit -m "build: bundle Claude spend collector"
```

- [ ] **Step 6: Run final checks**

```bash
node scripts/claude-usage-windows.test.js
swift test --package-path native/ai-widgets
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 7: Fresh unregister-first install**

Use `$fresh-install-native-widget`: stop the host, unregister the installed extension, move the exact old app and Claude graph cache to Trash, install with `native/ai-widgets/scripts/install-local-widget.sh`, verify the signature, and confirm exactly one PluginKit registration. If any command reports HTTP 429, wait 60 seconds and retry only that command.

- [ ] **Step 8: Verify live Today, 7D, and month data**

```bash
jq -e '([.claudeWindows[].period] | sort) == (["month","sevenDay","today"] | sort)' "$HOME/Library/Containers/com.ai-desktop-widgets.ai-widgets.widget/Data/Library/Application Support/AIWidgets/claude.json"
/usr/bin/log show --last 5m --style compact --predicate 'subsystem == "com.ai-desktop-widgets.ai-widgets.widget" AND category == "timeline"' | grep 'provider=claude snapshot=claude'
```

Expected: three periods are present and the current widget timeline loaded the Claude snapshot. Click the headline three times and confirm `Today → 7D → This month → Today`; Today/month show spend, while 7D shows its real percentage when available and otherwise spend.
