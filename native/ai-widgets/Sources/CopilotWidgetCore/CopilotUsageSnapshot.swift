import Foundation

public struct CopilotUsageSnapshot: Codable, Equatable, Sendable {
    public let observedAt: Date
    public let buckets: [UsageBucket]
    public let todayRequests: Int
    public let todayTokens: Int
    public let todayAIU: Double
    public let monthRequests: Int
    public let monthTokens: Int
    public let monthAIU: Double
    public let limitAIU: Double

    public init(
        observedAt: Date,
        buckets: [UsageBucket],
        todayRequests: Int,
        todayTokens: Int,
        todayAIU: Double,
        monthRequests: Int,
        monthTokens: Int,
        monthAIU: Double,
        limitAIU: Double
    ) {
        self.observedAt = observedAt
        self.buckets = buckets
        self.todayRequests = todayRequests
        self.todayTokens = todayTokens
        self.todayAIU = todayAIU
        self.monthRequests = monthRequests
        self.monthTokens = monthTokens
        self.monthAIU = monthAIU
        self.limitAIU = limitAIU
    }
}

public struct UsageBucket: Codable, Equatable, Sendable {
    public let bucket: Date
    public let model: String
    public let tokens: Int

    public init(bucket: Date, model: String, tokens: Int) {
        self.bucket = bucket
        self.model = model
        self.tokens = tokens
    }
}
