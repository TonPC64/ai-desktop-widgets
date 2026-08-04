import XCTest
@testable import CopilotWidgetCore

final class PresentationTests: XCTestCase {
    func testPercentagePresentationUsesMonthBudget() {
        let presentation = WidgetPresentation(snapshot: snapshot(monthAIU: 14_800, limitAIU: 126_000), mode: .percentage)

        XCTAssertEqual(presentation.heroText, "12%")
        XCTAssertEqual(presentation.detailText, "August usage · 14.8K / 126.0K AIU")
    }

    func testEstimatePresentationIsLabeledAndUsesExistingRate() {
        let presentation = WidgetPresentation(snapshot: snapshot(monthAIU: 14_800, limitAIU: 126_000), mode: .estimatedValue)

        XCTAssertEqual(presentation.heroText, "$148")
        XCTAssertEqual(presentation.detailText, "Estimated value · $1,260 budget")
    }

    private func snapshot(monthAIU: Double, limitAIU: Double) -> CopilotUsageSnapshot {
        .init(
            observedAt: Calendar(identifier: .gregorian).date(from: .init(year: 2026, month: 8, day: 4))!,
            buckets: [],
            todayRequests: 0,
            todayTokens: 0,
            todayAIU: 0,
            monthRequests: 0,
            monthTokens: 0,
            monthAIU: monthAIU,
            limitAIU: limitAIU
        )
    }
}
