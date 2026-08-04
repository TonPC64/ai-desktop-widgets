import AppIntents
#if canImport(CopilotWidgetCore)
import CopilotWidgetCore
#endif
import SwiftUI
import WidgetKit

public struct CopilotStatusWidget: Widget {
    public static let kind = CopilotWidgetPaths.widgetKind

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CopilotTimelineProvider()) { entry in
            CopilotStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Copilot Status")
        .description("Copilot CLI activity, models, and monthly AIU usage.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])

    }
}

#if WIDGET_EXTENSION
@main
struct CopilotStatusWidgetBundle: WidgetBundle {
    var body: some Widget {
        CopilotStatusWidget()
    }
}
#endif

struct CopilotEntry: TimelineEntry {
    let date: Date
    let snapshot: CopilotUsageSnapshot?
    let mode: PriceDisplayMode
}

struct CopilotTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CopilotEntry {
        .init(date: .now, snapshot: nil, mode: priceMode)
    }

    func getSnapshot(in context: Context, completion: @escaping (CopilotEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CopilotEntry>) -> Void) {
        let now = Date.now
        completion(.init(entries: [entry(date: now)], policy: .after(now.addingTimeInterval(300))))
    }

    private var priceMode: PriceDisplayMode {
        PriceDisplayMode(rawValue: UserDefaults.standard.string(forKey: TogglePriceModeIntent.key) ?? "") ?? .percentage
    }

    private func entry(date: Date = .now) -> CopilotEntry {
        let snapshot = try? SnapshotStore(url: CopilotWidgetPaths.extensionSnapshotURL()).load()
        return .init(date: date, snapshot: snapshot, mode: priceMode)
    }
}

struct CopilotStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CopilotEntry

    var body: some View {
        LiquidGlassView {
            if let snapshot = entry.snapshot {
                content(snapshot: snapshot)
            } else {
                unavailable
            }
        }
        .containerBackground(for: .widget) {
            // ubersicht card uses backdrop-filter blur(48px) which we can't do in a
            // widget snapshot; compensate with a denser base so it reads dark, not grey.
            Color(red: 18/255, green: 18/255, blue: 24/255).opacity(0.88)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.13),
                            Color.white.opacity(0.04),
                            Color(red: 100/255, green: 200/255, blue: 160/255).opacity(0.06)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        }
        .environment(\.colorScheme, .dark)
    }

    private func content(snapshot: CopilotUsageSnapshot) -> some View {
        let presentation = WidgetPresentation(snapshot: snapshot, mode: entry.mode)
        let models = Array(Set(snapshot.buckets.map(\.model))).sorted()
        let compact = family == .systemSmall
        let large = family == .systemLarge

        return VStack(alignment: .leading, spacing: large ? 10 : compact ? 5 : 6) {
            HStack {
                Text("COPILOT CLI").font(.system(size: large ? 12 : compact ? 9 : 10, weight: .semibold)).tracking(0.8)
                Spacer()
                Text("last 24h").foregroundStyle(.white.opacity(0.75))
            }
            .font(.system(size: large ? 11 : compact ? 8 : 9))
            .padding(.bottom, 2)
            usage(presentation: presentation, compact: compact, large: large)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule().fill(.blue)
                        .frame(width: geo.size.width * min(max(presentation.progress, 0), 1))
                }
            }
            .frame(height: 4)
            UsageChartView(buckets: snapshot.buckets, models: models, compact: compact)
                .frame(height: large ? 140 : compact ? 50 : 40)
            if compact {
                Text("\(models.count) models · Today \(compactAIU(snapshot.todayAIU)) AIU")
                    .font(.system(size: 8)).foregroundStyle(.white.opacity(0.75))
            } else {
                modelLegend(models, large: large)
                HStack {
                    Text("Today: \(compactAIU(snapshot.todayAIU)) AIU · \(compactTokens(snapshot.todayTokens)) tokens")
                    Spacer()
                    Text("\(snapshot.todayRequests) req")
                }
                .font(.system(size: large ? 10 : 8)).foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private func usage(presentation: WidgetPresentation, compact: Bool, large: Bool) -> some View {
        Button(intent: TogglePriceModeIntent()) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(presentation.heroText).font(.system(size: large ? 38 : compact ? 24 : 28, weight: .semibold)).contentTransition(.numericText())
                Text(presentation.detailText).font(.system(size: large ? 13 : compact ? 8 : 10)).lineLimit(1)
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func modelLegend(_ models: [String], large: Bool) -> some View {
        FlowLayout(spacing: 4) {
            ForEach(models, id: \.self) { model in
                HStack(spacing: 3) {
                    Circle().fill(WidgetModelPalette.color(model, models: models)).frame(width: large ? 7 : 5, height: large ? 7 : 5)
                    Text(model).lineLimit(1)
                }
                .font(.system(size: large ? 9 : 7)).foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("COPILOT CLI").font(.system(size: 10, weight: .semibold)).tracking(0.8)
            Spacer()
            Text("--").font(.system(size: 28, weight: .semibold))
            Text("No recent activity").font(.system(size: 10)).foregroundStyle(.white.opacity(0.75))
        }
    }

    private func compactAIU(_ value: Double) -> String {
        value >= 1_000 ? String(format: "%.1fK", value / 1_000) : String(format: "%.1f", value)
    }

    private func compactTokens(_ value: Int) -> String {
        value >= 1_000_000 ? "\(value / 1_000_000)M" : value >= 1_000 ? "\(value / 1_000)K" : "\(value)"
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var point = CGPoint.zero
        var height: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if point.x + size.width > width, point.x > 0 { point.x = 0; point.y += height + spacing; height = 0 }
            point.x += size.width + spacing
            height = max(height, size.height)
        }
        return .init(width: width, height: point.y + height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var point = bounds.origin
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if point.x + size.width > bounds.maxX, point.x > bounds.minX { point.x = bounds.minX; point.y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: point, proposal: .unspecified)
            point.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
