import Foundation

public enum CollectorPayload {
    public static func decode(_ data: Data, observedAt: Date) throws -> CopilotUsageSnapshot {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        let today = payload.todayArr.first
        let month = payload.monthArr.first

        return CopilotUsageSnapshot(
            observedAt: observedAt,
            buckets: payload.bins.map {
                UsageBucket(bucket: .init(timeIntervalSince1970: TimeInterval($0.bucket)), model: $0.model, tokens: $0.tok)
            },
            todayRequests: today?.requests ?? 0,
            todayTokens: today?.tokens ?? 0,
            todayAIU: today?.aiu ?? 0,
            monthRequests: month?.requests ?? 0,
            monthTokens: month?.tokens ?? 0,
            monthAIU: month?.aiu ?? 0,
            limitAIU: payload.limitAiu ?? 0
        )
    }

    private struct Payload: Decodable {
        private enum CodingKeys: String, CodingKey {
            case bins, todayArr, monthArr, limitAiu
        }

        let bins: [Bucket]
        let todayArr: [Summary]
        let monthArr: [Summary]
        let limitAiu: Double?

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            bins = try values.decodeIfPresent([Bucket].self, forKey: .bins) ?? []
            todayArr = try values.decodeIfPresent([Summary].self, forKey: .todayArr) ?? []
            monthArr = try values.decodeIfPresent([Summary].self, forKey: .monthArr) ?? []
            limitAiu = try values.decodeIfPresent(Double.self, forKey: .limitAiu)
        }
    }

    private struct Bucket: Decodable {
        let bucket: Int
        let model: String
        let tok: Int
    }

    private struct Summary: Decodable {
        let requests: Int?
        let tokens: Int?
        let aiu: Double?
    }
}
