import XCTest
@testable import CopilotWidgetCore

final class CollectorPayloadTests: XCTestCase {
    func testDecodesCollectorPayloadIntoAggregateSnapshot() throws {
        let data = Data(#"""
        {"bins":[{"bucket":1722780000,"model":"gpt-5.3-codex","tok":240}],
         "todayArr":[{"requests":2,"tokens":240,"aiu":1.7}],
         "monthArr":[{"requests":5,"tokens":600,"aiu":14.8}],"limitAiu":126000}
        """#.utf8)

        let snapshot = try CollectorPayload.decode(data, observedAt: .init(timeIntervalSince1970: 1))

        XCTAssertEqual(snapshot.monthAIU, 14.8)
        XCTAssertEqual(snapshot.buckets.map(\.model), ["gpt-5.3-codex"])
        XCTAssertEqual(snapshot.todayRequests, 2)
    }

    func testMissingArraysProduceZeroUsage() throws {
        let snapshot = try CollectorPayload.decode(Data(#"{"bins":[]}"#.utf8), observedAt: .now)

        XCTAssertEqual(snapshot.monthAIU, 0)
        XCTAssertTrue(snapshot.buckets.isEmpty)
    }
}
