import AppIntents
#if canImport(CopilotWidgetCore)
import CopilotWidgetCore
#endif
import WidgetKit

struct TogglePriceModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Copilot price estimate"
    static let key = "copilot.widget.price-display-mode"

    func perform() async throws -> some IntentResult {
        let current = PriceDisplayMode(rawValue: UserDefaults.standard.string(forKey: Self.key) ?? "") ?? .percentage
        UserDefaults.standard.set(current == .percentage ? PriceDisplayMode.estimatedValue.rawValue : PriceDisplayMode.percentage.rawValue, forKey: Self.key)
        WidgetCenter.shared.reloadTimelines(ofKind: CopilotWidgetPaths.widgetKind)
        return .result()
    }
}

struct CycleClaudeUsagePeriodIntent: AppIntent {
    static let title: LocalizedStringResource = "Change Claude usage period"
    static let key = "claude.widget.usage-period"

    func perform() async throws -> some IntentResult {
        let current = ClaudeUsagePeriod.fromStoredValue(UserDefaults.standard.string(forKey: Self.key))
        UserDefaults.standard.set(current.next.rawValue, forKey: Self.key)
        WidgetCenter.shared.reloadTimelines(ofKind: CopilotWidgetPaths.widgetKind)
        return .result()
    }
}

struct CycleCodexUsagePeriodIntent: AppIntent {
    static let title: LocalizedStringResource = "Change Codex usage period"
    static let key = "codex.widget.usage-period"

    func perform() async throws -> some IntentResult {
        let current = ClaudeUsagePeriod.fromStoredValue(UserDefaults.standard.string(forKey: Self.key))
        UserDefaults.standard.set(current.next.rawValue, forKey: Self.key)
        WidgetCenter.shared.reloadTimelines(ofKind: CopilotWidgetPaths.widgetKind)
        return .result()
    }
}
