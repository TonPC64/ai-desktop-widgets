#if canImport(CopilotWidgetCore)
import CopilotWidgetCore
#endif
import SwiftUI

struct UsageChartView: View {
    let buckets: [UsageBucket]
    let models: [String]
    let provider: AIProvider
    let chartStart: Date?
    let chartInterval: TimeInterval?
    let chartSlotCount: Int?
    let compact: Bool

    var body: some View {
        GeometryReader { proxy in
            let slots = slots
            let maximum = max(1, slots.map(\.total).max() ?? 1)
            HStack(alignment: .bottom, spacing: compact ? 1 : 2) {
                ForEach(slots) { slot in
                    VStack(spacing: 0) {
                        ForEach(models.reversed(), id: \.self) { model in
                            let tokens = slot.tokens[model] ?? 0
                            Rectangle().fill(WidgetModelPalette.color(model, models: models, provider: provider))
                                .frame(height: proxy.size.height * CGFloat(tokens) / CGFloat(maximum))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
        }
    }

    private var slots: [ChartSlot] {
        let grouped = Dictionary(grouping: buckets, by: { Int($0.bucket.timeIntervalSince1970) })
        if let chartStart, let chartInterval, let chartSlotCount {
            let start = Int(chartStart.timeIntervalSince1970)
            return (0..<chartSlotCount).map { offset in
                let timestamp = start + Int(chartInterval) * offset
                let values = grouped[timestamp, default: []]
                return .init(id: timestamp, tokens: Dictionary(values.map { ($0.model, $0.tokens) }, uniquingKeysWith: +))
            }
        }
        if provider == .claude { return [] }
        let now = Date.now.timeIntervalSince1970
        let start = Int((now - 86_400) / 1_800) * 1_800
        return stride(from: start, through: Int(now), by: 1_800).map { timestamp in
            let values = grouped[timestamp, default: []]
            return .init(id: timestamp, tokens: Dictionary(values.map { ($0.model, $0.tokens) }, uniquingKeysWith: +))
        }
    }
}

private struct ChartSlot: Identifiable {
    let id: Int
    let tokens: [String: Int]
    var total: Int { tokens.values.reduce(0, +) }
}

enum WidgetModelPalette {
    private static let colors: [Color] = [.purple, .teal, .pink, .green, .blue, .orange]

    static func color(_ model: String, models: [String], provider: AIProvider) -> Color {
        if provider == .claude {
            let hex = ClaudeModelPalette.hex(for: model)
            return Color(
                red: Double((hex >> 16) & 0xff) / 255,
                green: Double((hex >> 8) & 0xff) / 255,
                blue: Double(hex & 0xff) / 255
            )
        }
        return colors[(models.firstIndex(of: model) ?? 0) % colors.count]
    }
}
