import AppIntents
#if canImport(CopilotWidgetCore)
import CopilotWidgetCore
#endif
import OSLog
import SwiftUI
import WidgetKit

public struct CopilotStatusWidget: Widget {
    public static let kind = CopilotWidgetPaths.widgetKind

    public init() {}

    public var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: ProviderConfigurationIntent.self, provider: CopilotTimelineProvider()) { entry in
            CopilotStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("AI Status")
        .description("Copilot, Claude, or Codex activity and quota.")
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
    let snapshot: AIProviderSnapshot?
    let selection: WidgetProviderSelection
    let mode: PriceDisplayMode
    let claudePeriod: ClaudeUsagePeriod
    let codexPeriod: ClaudeUsagePeriod
}

struct CopilotTimelineProvider: AppIntentTimelineProvider {
    typealias Intent = ProviderConfigurationIntent
    private let logger = Logger(subsystem: CopilotWidgetPaths.widgetBundleIdentifier, category: "timeline")

    func placeholder(in context: Context) -> CopilotEntry {
        .init(date: .now, snapshot: nil, selection: .required, mode: priceMode, claudePeriod: claudePeriod, codexPeriod: codexPeriod)
    }

    func snapshot(for configuration: ProviderConfigurationIntent, in context: Context) async -> CopilotEntry {
        entry(selection: .init(rawValue: configuration.provider))
    }

    func timeline(for configuration: ProviderConfigurationIntent, in context: Context) async -> Timeline<CopilotEntry> {
        let now = Date.now
        return .init(entries: [entry(selection: .init(rawValue: configuration.provider), date: now)], policy: .after(now.addingTimeInterval(300)))
    }

    private var priceMode: PriceDisplayMode {
        PriceDisplayMode(rawValue: UserDefaults.standard.string(forKey: TogglePriceModeIntent.key) ?? "") ?? .percentage
    }

    private var claudePeriod: ClaudeUsagePeriod {
        ClaudeUsagePeriod.fromStoredValue(UserDefaults.standard.string(forKey: CycleClaudeUsagePeriodIntent.key))
    }

    private var codexPeriod: ClaudeUsagePeriod {
        ClaudeUsagePeriod.fromStoredValue(UserDefaults.standard.string(forKey: CycleCodexUsagePeriodIntent.key))
    }

    private func entry(selection: WidgetProviderSelection, date: Date = .now) -> CopilotEntry {
        let snapshot: AIProviderSnapshot?
        if case .selected(let provider) = selection {
            snapshot = try? SnapshotStore(applicationSupportDirectory: CopilotWidgetPaths.extensionApplicationSupportDirectory()).load(provider: provider)
            logger.notice("provider=\(provider.rawValue, privacy: .public) snapshot=\(snapshot?.provider.rawValue ?? "missing", privacy: .public)")
        } else {
            snapshot = nil
            logger.notice("provider=missing snapshot=missing")
        }
        return .init(date: date, snapshot: snapshot, selection: selection, mode: priceMode, claudePeriod: claudePeriod, codexPeriod: codexPeriod)
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

    private func content(snapshot: AIProviderSnapshot) -> some View {
        let claudePresentation = snapshot.provider == .claude ? snapshot.claudePresentation(for: entry.claudePeriod) : nil
        let codexPresentation = snapshot.provider == .codex ? snapshot.codexPresentation(for: entry.codexPeriod) : nil
        let presentation = claudePresentation ?? codexPresentation
        let heroText = presentation?.heroText ?? (entry.mode == .estimatedValue ? (snapshot.alternateHeroText ?? snapshot.heroText) : snapshot.heroText)
        let detailText = presentation?.detailText ?? (entry.mode == .estimatedValue ? (snapshot.alternateDetailText ?? snapshot.detailText) : snapshot.detailText)
        let buckets = presentation?.buckets ?? snapshot.buckets
        let models = presentation?.models ?? snapshot.models
        let compact = family == .systemSmall
        let large = family == .systemLarge

        return VStack(alignment: .leading, spacing: large ? 10 : compact ? 5 : 6) {
            HStack {
                Text(snapshot.title).font(.system(size: large ? 12 : compact ? 9 : 10, weight: .semibold)).tracking(0.8)
                Spacer()
                Text(presentation?.headerLabel ?? "last 24h").foregroundStyle(.white.opacity(0.75))
            }
            .font(.system(size: large ? 11 : compact ? 8 : 9))
            .padding(.bottom, 2)
            providerSummary(snapshot: snapshot, heroText: heroText, detailText: detailText, compact: compact, large: large)
            UsageChartView(
                buckets: buckets,
                models: models,
                provider: snapshot.provider,
                chartStart: presentation?.chartStart,
                chartInterval: presentation?.chartInterval,
                chartSlotCount: presentation?.chartSlotCount,
                compact: compact
            )
                .frame(height: large ? 140 : compact ? 50 : 40)
            if !compact {
                modelLegend(models, large: large)
            } else {
                Text("\(models.count) models")
                    .font(.system(size: 8)).foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    @ViewBuilder
    private func providerSummary(snapshot: AIProviderSnapshot, heroText: String, detailText: String, compact: Bool, large: Bool) -> some View {
        usage(snapshot: snapshot, heroText: heroText, detailText: detailText, compact: compact, large: large)
        if snapshot.provider == .copilot {
            progressBar(snapshot.progress, color: .blue)
        }
        metricRow(snapshot.metrics, compact: compact)
        if snapshot.provider == .claude {
            quotaRows(snapshot.quotas, color: accent(for: snapshot.provider), compact: compact)
        }
    }

    private func progressBar(_ value: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25))
                Capsule().fill(color).frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 4)
    }

    private func metricRow(_ metrics: [ProviderMetric], compact: Bool) -> some View {
        HStack(spacing: compact ? 8 : 14) {
            ForEach(metrics, id: \.label) { metric in
                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.label.uppercased()).font(.system(size: compact ? 7 : 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                    Text(metric.value).font(.system(size: compact ? 9 : 11, weight: .medium)).lineLimit(1)
                }
                if metric.label != metrics.last?.label { Spacer(minLength: 0) }
            }
        }
    }

    private func quotaRows(_ quotas: [ProviderQuota], color: Color, compact: Bool) -> some View {
        VStack(spacing: compact ? 3 : 5) {
            ForEach(quotas, id: \.label) { quota in
                HStack(spacing: 6) {
                    Text(quota.label).font(.system(size: compact ? 8 : 9, weight: .semibold)).frame(width: 22, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.16))
                            Capsule().fill(color).frame(width: geo.size.width * min(max(quota.usedPercent / 100, 0), 1))
                        }
                    }
                    .frame(height: compact ? 3 : 4)
                    Text("\(Int(quota.usedPercent.rounded()))%")
                        .font(.system(size: compact ? 8 : 9)).foregroundStyle(.white.opacity(0.75)).frame(width: 28, alignment: .trailing)
                }
            }
        }
    }

    private func accent(for provider: AIProvider) -> Color {
        switch provider {
        case .copilot: return .blue
        case .claude: return .orange
        case .codex: return .purple
        }
    }

    private func usage(snapshot: AIProviderSnapshot, heroText: String, detailText: String, compact: Bool, large: Bool) -> some View {
        Group {
            if snapshot.provider == .claude {
                Button(intent: CycleClaudeUsagePeriodIntent()) {
                    usageText(heroText: heroText, detailText: detailText, compact: compact, large: large)
                }
                .buttonStyle(.plain)
            } else if snapshot.provider == .codex {
                Button(intent: CycleCodexUsagePeriodIntent()) {
                    usageText(heroText: heroText, detailText: detailText, compact: compact, large: large)
                }
                .buttonStyle(.plain)
            } else if snapshot.priceModeSupported {
                Button(intent: TogglePriceModeIntent()) {
                    usageText(heroText: heroText, detailText: detailText, compact: compact, large: large)
                }
                .buttonStyle(.plain)
            } else {
                usageText(heroText: heroText, detailText: detailText, compact: compact, large: large)
            }
        }
    }

    private func usageText(heroText: String, detailText: String, compact: Bool, large: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(heroText).font(.system(size: large ? 38 : compact ? 24 : 28, weight: .semibold)).contentTransition(.numericText())
            Text(detailText).font(.system(size: large ? 13 : compact ? 8 : 10)).lineLimit(1)
        }
        .foregroundStyle(.white)
    }

    private func modelLegend(_ models: [String], large: Bool) -> some View {
        FlowLayout(spacing: 4) {
            ForEach(models, id: \.self) { model in
                HStack(spacing: 3) {
                    Circle().fill(WidgetModelPalette.color(model, models: models, provider: entry.snapshot?.provider ?? .copilot)).frame(width: large ? 7 : 5, height: large ? 7 : 5)
                    Text(model).lineLimit(1)
                }
                .font(.system(size: large ? 9 : 7)).foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(unavailableTitle).font(.system(size: 10, weight: .semibold)).tracking(0.8)
            Spacer()
            Text(unavailableHero).font(.system(size: 20, weight: .semibold))
            Text(unavailableDetail).font(.system(size: 10)).foregroundStyle(.white.opacity(0.75))
        }
    }

    private var unavailableTitle: String {
        if case .selected(let provider) = entry.selection { return provider.displayName.uppercased() }
        return "AI STATUS"
    }

    private var unavailableHero: String {
        if case .selected = entry.selection { return "--" }
        return "Choose provider"
    }

    private var unavailableDetail: String {
        if case .selected = entry.selection { return "No recent activity" }
        return "Right-click widget → Edit → Provider"
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
