import AppIntents
import Foundation

public enum AIProvider: String, Codable, CaseIterable, AppEnum, Sendable {
    case copilot, claude, codex

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "AI provider")
    public static let caseDisplayRepresentations: [AIProvider: DisplayRepresentation] = [
        .copilot: "Copilot",
        .claude: "Claude",
        .codex: "Codex"
    ]

    public var displayName: String { rawValue.capitalized }
}

public enum WidgetProviderSelection: Equatable, Sendable {
    case required
    case selected(AIProvider)

    public init(provider: AIProvider?) {
        self = provider.map(Self.selected) ?? .required
    }

    public init(rawValue: String?) {
        self.init(provider: rawValue.flatMap { AIProvider(rawValue: $0.lowercased()) })
    }
}

public struct ProviderMetric: Codable, Equatable, Sendable {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

public struct ProviderQuota: Codable, Equatable, Sendable {
    public let label: String
    public let usedPercent: Double
    public let detail: String?

    public init(label: String, usedPercent: Double, detail: String? = nil) {
        self.label = label
        self.usedPercent = usedPercent
        self.detail = detail
    }
}

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

public struct ClaudeUsagePresentation: Equatable, Sendable {
    public let headerLabel: String
    public let heroText: String
    public let detailText: String
    public let buckets: [UsageBucket]
    public let models: [String]
    public let chartStart: Date?
    public let chartInterval: TimeInterval?
    public let chartSlotCount: Int?
}

public struct AIProviderSnapshot: Codable, Equatable, Sendable {
    public let provider: AIProvider
    public let observedAt: Date
    public let title: String
    public let heroText: String
    public let detailText: String
    public let alternateHeroText: String?
    public let alternateDetailText: String?
    public let progress: Double
    public let buckets: [UsageBucket]
    public let models: [String]
    public let priceModeSupported: Bool
    public let metrics: [ProviderMetric]
    public let quotas: [ProviderQuota]
    public let claudeWindows: [ClaudeUsageWindow]?

    public init(
        provider: AIProvider,
        observedAt: Date,
        title: String,
        heroText: String,
        detailText: String,
        alternateHeroText: String? = nil,
        alternateDetailText: String? = nil,
        progress: Double,
        buckets: [UsageBucket],
        models: [String],
        priceModeSupported: Bool,
        metrics: [ProviderMetric] = [],
        quotas: [ProviderQuota] = [],
        claudeWindows: [ClaudeUsageWindow]? = nil
    ) {
        self.provider = provider
        self.observedAt = observedAt
        self.title = title
        self.heroText = heroText
        self.detailText = detailText
        self.alternateHeroText = alternateHeroText
        self.alternateDetailText = alternateDetailText
        self.progress = progress
        self.buckets = buckets
        self.models = models
        self.priceModeSupported = priceModeSupported
        self.metrics = metrics
        self.quotas = quotas
        self.claudeWindows = claudeWindows
    }

    public func claudeWindow(for period: ClaudeUsagePeriod) -> ClaudeUsageWindow? {
        claudeWindows?.first { $0.period == period }
    }

    public func claudePresentation(for period: ClaudeUsagePeriod) -> ClaudeUsagePresentation {
        guard let window = claudeWindow(for: period) else {
            return .init(
                headerLabel: period.headerLabel,
                heroText: "--",
                detailText: "No \(period.usageLabel) usage data",
                buckets: [],
                models: [],
                chartStart: nil,
                chartInterval: nil,
                chartSlotCount: nil
            )
        }
        return .init(
            headerLabel: period.headerLabel,
            heroText: window.heroText,
            detailText: window.detailText,
            buckets: window.buckets,
            models: window.models,
            chartStart: window.chartStart,
            chartInterval: window.chartInterval,
            chartSlotCount: window.chartSlotCount
        )
    }
}

public enum ProviderPayload {
    public static func decode(provider: AIProvider, data: Data, observedAt: Date) throws -> AIProviderSnapshot {
        switch provider {
        case .copilot:
            let snapshot = try CollectorPayload.decode(data, observedAt: observedAt)
            let presentation = WidgetPresentation(snapshot: snapshot, mode: .percentage)
            return .init(
                provider: provider, observedAt: observedAt, title: "COPILOT CLI",
                heroText: presentation.heroText, detailText: presentation.detailText,
                alternateHeroText: WidgetPresentation(snapshot: snapshot, mode: .estimatedValue).heroText,
                alternateDetailText: WidgetPresentation(snapshot: snapshot, mode: .estimatedValue).detailText,
                progress: presentation.progress, buckets: snapshot.buckets,
                models: Array(Set(snapshot.buckets.map(\.model))).sorted(), priceModeSupported: true,
                metrics: [
                    .init(label: "Today", value: "\(String(format: "%.1f", snapshot.todayAIU)) AIU"),
                    .init(label: "Tokens", value: compact(Double(snapshot.todayTokens))),
                    .init(label: "Requests", value: "\(snapshot.todayRequests)")
                ]
            )
        case .claude:
            return try decodeClaude(data, observedAt: observedAt)
        case .codex:
            return try decodeCodex(data, observedAt: observedAt)
        }
    }

    private static func decodeClaude(_ data: Data, observedAt: Date) throws -> AIProviderSnapshot {
        let payload = try JSONDecoder().decode(ClaudePayload.self, from: data)
        let sevenDayQuota = payload.quota?.sevenDay?.pct
        let buckets = payload.bins.flatMap { bin in
            bin.models.map { UsageBucket(bucket: Date(timeIntervalSince1970: TimeInterval(bin.t) / 1000), model: $0.key, tokens: $0.value) }
        }
        let claudeWindows = payload.usageWindows.map { windows in
            [
                windows.today.map { claudeUsageWindow(period: .today, payload: $0, quota: nil) },
                windows.sevenDay.map { claudeUsageWindow(period: .sevenDay, payload: $0, quota: payload.quota?.sevenDay) },
                windows.month.map { claudeUsageWindow(period: .month, payload: $0, quota: nil) }
            ].compactMap { $0 }
        }
        let todayWindow = claudeWindows?.first { $0.period == .today }
        let fallbackDetail = payload.month?.tokens.map { "\(compact($0)) tokens · Today usage" } ?? "No Today usage data"
        let heroText = todayWindow?.heroText ?? "--"
        let detailText = todayWindow?.detailText ?? fallbackDetail
        let quotas: [ProviderQuota] = [
            sevenDayQuota.map { .init(label: "7D", usedPercent: $0) }
        ].compactMap { $0 }
        let metrics: [ProviderMetric] = [
            sevenDayQuota.map { .init(label: "7D", value: "\(Int($0.rounded()))%") },
            payload.month?.tokens.map { .init(label: "Month", value: "\(compact($0)) tokens") }
        ].compactMap { $0 }
        return .init(
            provider: .claude, observedAt: observedAt, title: "CLAUDE CODE",
            heroText: heroText, detailText: detailText,
            progress: 0, buckets: buckets,
            models: Array(Set(buckets.map(\.model))).sorted(), priceModeSupported: false,
            metrics: metrics,
            quotas: quotas,
            claudeWindows: claudeWindows
        )
    }

    private static func claudeUsageWindow(period: ClaudeUsagePeriod, payload: ClaudeUsageWindowPayload, quota: ClaudeWindow?) -> ClaudeUsageWindow {
        let buckets = payload.bins.flatMap { bin in
            bin.models.map { UsageBucket(bucket: Date(timeIntervalSince1970: TimeInterval(bin.t) / 1000), model: $0.key, tokens: $0.value) }
        }
        let binTokens = payload.bins.flatMap { $0.models.values }
        let tokens = payload.tokens ?? (binTokens.isEmpty ? nil : Double(binTokens.reduce(0, +)))
        let label = period.usageLabel
        return .init(
            period: period,
            heroText: quota.map { "\(Int($0.pct.rounded()))%" } ?? payload.cost.map(claudeDollars) ?? "--",
            detailText: tokens.map { "\(compact($0)) tokens · \(label) usage" } ?? "Tokens unavailable · \(label) usage",
            buckets: buckets,
            models: Array(Set(buckets.map(\.model))).sorted(),
            chartStart: Date(timeIntervalSince1970: TimeInterval(payload.start) / 1000),
            chartInterval: TimeInterval(payload.bucketMs) / 1000,
            chartSlotCount: payload.bins.count
        )
    }

    private static func claudeDollars(_ value: Double) -> String {
        value.rounded() == value ? "$\(Int(value))" : String(format: "$%.2f", value)
    }

    private static func decodeCodex(_ data: Data, observedAt: Date) throws -> AIProviderSnapshot {
        let payload = try JSONDecoder().decode(CodexPayload.self, from: data)
        let used = payload.quota.first?.usedPercent ?? 0
        let buckets = payload.bins.map {
            UsageBucket(bucket: Date(timeIntervalSince1970: TimeInterval($0.bucket) / 1000), model: $0.model, tokens: $0.tokens)
        }
        return .init(
            provider: .codex, observedAt: observedAt, title: "CODEX",
            heroText: String(format: "$%.2f", payload.monthCost ?? 0),
            detailText: "\(compact(Double(payload.monthTokens))) tokens · \(payload.quota.first?.label ?? "Quota") quota",
            progress: min(max(used / 100, 0), 1), buckets: buckets,
            models: Array(Set(buckets.map(\.model))).sorted(), priceModeSupported: false,
            metrics: [
                .init(label: "Month", value: String(format: "$%.2f", payload.monthCost ?? 0)),
                .init(label: "Context", value: payload.current.map { "\(Int((Double($0.tokens) / Double(max($0.contextWindow, 1)) * 100).rounded()))%" } ?? "--")
            ],
            quotas: payload.quota.map { .init(label: $0.label, usedPercent: $0.usedPercent, detail: "\(Int($0.remainingPercent.rounded()))% left") }
        )
    }

    private static func compact(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        return value >= 1_000 ? String(format: "%.1fK", value / 1_000) : String(format: "%.0f", value)
    }

    private struct ClaudePayload: Decodable {
        let bins: [ClaudeBin]
        let quota: ClaudeQuota?
        let month: ClaudeMonth?
        let usageWindows: ClaudeUsageWindowsPayload?
    }

    private struct ClaudeBin: Decodable {
        let t: Int64
        let models: [String: Int]
    }

    private struct ClaudeQuota: Decodable {
        let fiveHour: ClaudeWindow?
        let sevenDay: ClaudeWindow?
    }

    private struct ClaudeWindow: Decodable {
        let pct: Double
    }

    private struct ClaudeUsageWindowsPayload: Decodable {
        let today: ClaudeUsageWindowPayload?
        let sevenDay: ClaudeUsageWindowPayload?
        let month: ClaudeUsageWindowPayload?
    }

    private struct ClaudeUsageWindowPayload: Decodable {
        let start: Int64
        let bucketMs: Int64
        let cost: Double?
        let tokens: Double?
        let bins: [ClaudeBin]
    }

    private struct ClaudeMonth: Decodable {
        let tokens: Double?
    }

    private struct CodexPayload: Decodable {
        let bins: [CodexBin]
        let quota: [CodexWindow]
        let monthTokens: Int
        let monthCost: Double?
        let current: CodexCurrent?
    }

    private struct CodexBin: Decodable {
        let bucket: Int64
        let model: String
        let tokens: Int
    }

    private struct CodexWindow: Decodable {
        let label: String
        let usedPercent: Double
        let remainingPercent: Double
    }

    private struct CodexCurrent: Decodable {
        let tokens: Int
        let contextWindow: Int
    }
}
