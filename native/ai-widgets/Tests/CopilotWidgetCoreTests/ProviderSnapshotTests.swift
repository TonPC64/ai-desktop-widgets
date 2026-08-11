import XCTest
@testable import CopilotWidgetCore

final class ProviderSnapshotTests: XCTestCase {
    func testMissingProviderRequiresSelectionInsteadOfFallingBack() {
        XCTAssertEqual(WidgetProviderSelection(provider: nil), .required)
        XCTAssertEqual(WidgetProviderSelection(provider: .claude), .selected(.claude))
    }

    func testProviderSelectionDecodesConfiguredString() {
        XCTAssertEqual(WidgetProviderSelection(rawValue: "Codex"), .selected(.codex))
        XCTAssertEqual(WidgetProviderSelection(rawValue: nil), .required)
        XCTAssertEqual(WidgetProviderSelection(rawValue: "unknown"), .required)
    }

    func testDecodesCopilotPayload() throws {
        let snapshot = try ProviderPayload.decode(
            provider: .copilot,
            data: Data(#"{"bins":[],"todayArr":[{"requests":2,"tokens":100,"aiu":4}],"monthArr":[{"requests":5,"tokens":250,"aiu":12}],"limitAiu":100}"#.utf8),
            observedAt: date
        )

        XCTAssertEqual(snapshot.provider, .copilot)
        XCTAssertEqual(snapshot.heroText, "12%")
        XCTAssertEqual(snapshot.detailText, "August usage · 12 / 100 AIU")
        XCTAssertEqual(snapshot.metrics, [
            .init(label: "Today", value: "4.0 AIU"),
            .init(label: "Tokens", value: "100"),
            .init(label: "Requests", value: "2")
        ])
    }

    func testDecodesClaudePayload() throws {
        let snapshot = try ProviderPayload.decode(
            provider: .claude,
            data: Data(#"{"bins":[{"t":1722780000000,"models":{"sonnet":240}}],"quota":{"fiveHour":{"pct":25},"sevenDay":{"pct":40}},"month":{"tokens":1000000,"cost":2.5},"usageWindows":{"today":{"start":1722762000000,"end":1722780000000,"bucketMs":600000,"cost":1.16,"tokens":3400000,"bins":[{"t":1722762000000,"models":{"sonnet":3400000}}]},"sevenDay":{"start":1722175200000,"end":1722780000000,"bucketMs":14400000,"cost":126,"tokens":99000000,"bins":[{"t":1722175200000,"models":{"opus":99000000}}]}}}"#.utf8),
            observedAt: date
        )

        XCTAssertEqual(snapshot.provider, .claude)
        XCTAssertEqual(snapshot.heroText, "$1.16")
        XCTAssertEqual(snapshot.detailText, "3.4M tokens · Today usage")
        XCTAssertEqual(snapshot.buckets.first?.model, "sonnet")
        XCTAssertEqual(snapshot.quotas.map(\.label), ["7D"])
        XCTAssertEqual(snapshot.metrics.first?.value, "40%")
        XCTAssertEqual(snapshot.claudeWindow(for: .today)?.heroText, "$1.16")
        XCTAssertEqual(snapshot.claudeWindow(for: .sevenDay)?.heroText, "40%")
    }

    func testDecodesClaudeUsageWindowsWithoutOAuthQuota() throws {
        let snapshot = try ProviderPayload.decode(
            provider: .claude,
            data: Data(#"{"bins":[],"quota":null,"usageWindows":{"today":{"start":1722762000000,"end":1722780000000,"bucketMs":600000,"cost":1.16,"tokens":3400000,"bins":[{"t":1722762000000,"models":{"sonnet":3400000}}]},"sevenDay":{"start":1722175200000,"end":1722780000000,"bucketMs":14400000,"cost":126,"tokens":99000000,"bins":[{"t":1722175200000,"models":{"opus":99000000}}]},"month":{"start":1722470400000,"end":1722780000000,"bucketMs":86400000,"cost":248.5,"tokens":175000000,"bins":[{"t":1722470400000,"models":{"sonnet":175000000}}]}}}"#.utf8),
            observedAt: date
        )

        XCTAssertEqual(snapshot.quotas, [])
        XCTAssertEqual(snapshot.claudeWindow(for: .today)?.heroText, "$1.16")
        XCTAssertEqual(snapshot.claudeWindow(for: .today)?.detailText, "3.4M tokens · Today usage")
        XCTAssertEqual(snapshot.claudeWindow(for: .sevenDay)?.heroText, "$126")
        let month = snapshot.claudePresentation(for: .month)
        XCTAssertEqual(month.heroText, "$248.50")
        XCTAssertEqual(month.detailText, "175.0M tokens · Month usage")
        XCTAssertEqual(month.buckets.first?.model, "sonnet")
        XCTAssertEqual(month.chartInterval, 86_400)
        XCTAssertEqual(month.chartSlotCount, 1)
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

    func testClaudePartialQuotaUsesCostAndOmitsMissingQuotaRows() throws {
        let snapshot = try ProviderPayload.decode(
            provider: .claude,
            data: Data(#"{"bins":[],"quota":{"sevenDay":{"pct":40}},"month":{"tokens":1000000},"usageWindows":{"today":{"start":1722762000000,"end":1722780000000,"bucketMs":600000,"cost":1.16,"tokens":3400000,"bins":[{"t":1722762000000,"models":{"sonnet":3400000}}]},"sevenDay":{"start":1722175200000,"end":1722780000000,"bucketMs":14400000,"cost":126,"tokens":99000000,"bins":[{"t":1722175200000,"models":{"opus":99000000}}]}}}"#.utf8),
            observedAt: date
        )

        XCTAssertEqual(snapshot.heroText, "$1.16")
        XCTAssertEqual(snapshot.quotas, [.init(label: "7D", usedPercent: 40)])
        XCTAssertEqual(snapshot.metrics, [
            .init(label: "7D", value: "40%"),
            .init(label: "Month", value: "1.0M tokens")
        ])
    }

    func testClaudeNullAggregatesDoNotRenderSyntheticZeroes() throws {
        let snapshot = try ProviderPayload.decode(
            provider: .claude,
            data: Data(#"{"bins":[],"quota":null,"usageWindows":{"today":{"start":1722762000000,"end":1722780000000,"bucketMs":600000,"cost":null,"tokens":null,"bins":[{"t":1722762000000,"models":{"sonnet":3400000}}]},"sevenDay":{"start":1722175200000,"end":1722780000000,"bucketMs":14400000,"cost":null,"tokens":null,"bins":[]}}}"#.utf8),
            observedAt: date
        )

        let today = try XCTUnwrap(snapshot.claudeWindow(for: .today))
        XCTAssertEqual(today.heroText, "--")
        XCTAssertEqual(today.detailText, "3.4M tokens · Today usage")
        let sevenDay = try XCTUnwrap(snapshot.claudeWindow(for: .sevenDay))
        XCTAssertEqual(sevenDay.heroText, "--")
        XCTAssertEqual(sevenDay.detailText, "Tokens unavailable · 7D usage")
    }

    func testClaudeWithoutQuotaOrTodayWindowShowsNoQuotaPercentage() throws {
        let snapshot = try ProviderPayload.decode(
            provider: .claude,
            data: Data(#"{"bins":[],"quota":null}"#.utf8),
            observedAt: date
        )

        XCTAssertEqual(snapshot.heroText, "--")
        XCTAssertEqual(snapshot.quotas, [])
        XCTAssertEqual(snapshot.metrics, [])
    }

    func testClaudeUsagePeriodsCycleAndMigrateFiveHour() {
        XCTAssertEqual(ClaudeUsagePeriod.today.next, .sevenDay)
        XCTAssertEqual(ClaudeUsagePeriod.sevenDay.next, .month)
        XCTAssertEqual(ClaudeUsagePeriod.month.next, .today)
        XCTAssertEqual(ClaudeUsagePeriod.fromStoredValue("fiveHour"), .today)
        XCTAssertEqual(ClaudeUsagePeriod.fromStoredValue("sevenDay"), .sevenDay)
        XCTAssertEqual(ClaudeUsagePeriod.fromStoredValue(nil), .today)
    }

    func testClaudeUsagePeriodHeaderLabelsMatchSelectedPeriod() {
        XCTAssertEqual(ClaudeUsagePeriod.today.headerLabel, "today")
        XCTAssertEqual(ClaudeUsagePeriod.sevenDay.headerLabel, "last 7d")
        XCTAssertEqual(ClaudeUsagePeriod.month.headerLabel, "this month")
    }

    func testClaudePresentationDoesNotFallbackWhenSelectedWindowIsMissing() throws {
        let snapshot = try ProviderPayload.decode(
            provider: .claude,
            data: Data(#"{"bins":[{"t":1722780000000,"models":{"sonnet":240}}],"quota":{"fiveHour":{"pct":25}},"usageWindows":{"today":{"start":1722762000000,"end":1722780000000,"bucketMs":600000,"cost":1.16,"tokens":3400000,"bins":[{"t":1722762000000,"models":{"sonnet":3400000}}]}}}"#.utf8),
            observedAt: date
        )

        let presentation = snapshot.claudePresentation(for: .month)

        XCTAssertEqual(presentation.headerLabel, "this month")
        XCTAssertEqual(presentation.heroText, "--")
        XCTAssertEqual(presentation.detailText, "No Month usage data")
        XCTAssertEqual(presentation.buckets, [])
        XCTAssertEqual(presentation.models, [])
        XCTAssertNil(presentation.chartStart)
        XCTAssertNil(presentation.chartInterval)
        XCTAssertNil(presentation.chartSlotCount)
    }

    func testClaudeModelPaletteMatchesUbersichtColors() {
        XCTAssertEqual(ClaudeModelPalette.hex(for: "claude-opus-4-8"), 0x199E70)
        XCTAssertEqual(ClaudeModelPalette.hex(for: "sonnet-4-6"), 0xC98500)
        XCTAssertEqual(ClaudeModelPalette.hex(for: "haiku-4-5"), 0xE66767)
        XCTAssertEqual(ClaudeModelPalette.hex(for: "fable-1"), 0x3987E5)
        XCTAssertEqual(ClaudeModelPalette.hex(for: "unknown"), 0x898781)
    }

    func testDecodesCodexPayload() throws {
        let snapshot = try ProviderPayload.decode(
            provider: .codex,
            data: Data(#"{"bins":[{"bucket":1722780000000,"model":"sol","tokens":240}],"quota":[{"label":"5H","usedPercent":30,"remainingPercent":70}],"monthTokens":1200000,"monthCost":12.34,"current":{"tokens":500,"contextWindow":1000}}"#.utf8),
            observedAt: date
        )

        XCTAssertEqual(snapshot.provider, .codex)
        XCTAssertEqual(snapshot.heroText, "$12.34")
        XCTAssertEqual(snapshot.detailText, "1.2M tokens · 5H quota")
        XCTAssertEqual(snapshot.buckets.first?.bucket.timeIntervalSince1970, 1_722_780_000)
        XCTAssertEqual(snapshot.buckets.first?.model, "sol")
        XCTAssertEqual(snapshot.metrics, [
            .init(label: "Month", value: "$12.34"),
            .init(label: "Context", value: "50%")
        ])
    }

    private let date = Calendar(identifier: .gregorian).date(from: .init(year: 2026, month: 8, day: 4))!
}
