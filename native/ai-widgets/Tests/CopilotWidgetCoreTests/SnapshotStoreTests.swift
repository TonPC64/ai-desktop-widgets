import XCTest
@testable import CopilotWidgetCore

final class SnapshotStoreTests: XCTestCase {
    func testStoreRoundTripsSnapshot() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = SnapshotStore(url: url)
        let expected = CopilotUsageSnapshot(
            observedAt: .init(timeIntervalSince1970: 1),
            buckets: [.init(bucket: .init(timeIntervalSince1970: 2), model: "gpt-5.3-codex", tokens: 240)],
            todayRequests: 2,
            todayTokens: 240,
            todayAIU: 1.7,
            monthRequests: 5,
            monthTokens: 600,
            monthAIU: 14.8,
            limitAIU: 126_000
        )

        try store.save(expected)

        XCTAssertEqual(try store.load(), expected)
    }
}
