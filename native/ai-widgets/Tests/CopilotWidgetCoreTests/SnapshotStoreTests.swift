import XCTest
@testable import CopilotWidgetCore

final class SnapshotStoreTests: XCTestCase {
    func testWidgetKindUsesConfiguredWidgetVersion() {
        XCTAssertEqual(CopilotWidgetPaths.widgetKind, "com.ai-desktop-widgets.ai-widgets.v3")
    }

    func testStoreKeepsProviderSnapshotsSeparate() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
        let store = SnapshotStore(applicationSupportDirectory: directory)
        let copilot = AIProviderSnapshot(provider: .copilot, observedAt: .now, title: "COPILOT", heroText: "1%", detailText: "c", progress: 0.01, buckets: [], models: [], priceModeSupported: true)
        let codex = AIProviderSnapshot(provider: .codex, observedAt: .now, title: "CODEX", heroText: "2%", detailText: "x", progress: 0.02, buckets: [], models: [], priceModeSupported: false)

        try store.save(copilot, provider: .copilot)
        try store.save(codex, provider: .codex)

        XCTAssertEqual(try store.load(provider: .copilot), copilot)
        XCTAssertEqual(try store.load(provider: .codex), codex)
    }

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
