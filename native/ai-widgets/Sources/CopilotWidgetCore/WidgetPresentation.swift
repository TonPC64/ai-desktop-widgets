import Foundation

public enum PriceDisplayMode: String, Codable, Sendable {
    case percentage
    case estimatedValue
}

public struct WidgetPresentation: Equatable, Sendable {
    public let heroText: String
    public let detailText: String
    public let progress: Double

    public init(snapshot: CopilotUsageSnapshot, mode: PriceDisplayMode) {
        progress = snapshot.limitAIU > 0 ? min(max(snapshot.monthAIU / snapshot.limitAIU, 0), 1) : 0
        switch mode {
        case .percentage:
            heroText = "\(Int((progress * 100).rounded()))%"
            let month = snapshot.observedAt.formatted(.dateTime.month(.wide))
            detailText = "\(month) usage · \(Self.compact(snapshot.monthAIU)) / \(Self.compact(snapshot.limitAIU)) AIU"
        case .estimatedValue:
            heroText = Self.dollars(snapshot.monthAIU)
            detailText = "Estimated value · \(Self.dollars(snapshot.limitAIU)) budget"
        }
    }

    private static func compact(_ value: Double) -> String {
        if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        }
        return String(format: "%.0f", value)
    }

    private static func dollars(_ aiu: Double) -> String {
        "$\(Int((aiu * 0.01).rounded()).formatted(.number.grouping(.automatic)))"
    }
}
