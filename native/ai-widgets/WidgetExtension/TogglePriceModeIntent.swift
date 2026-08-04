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
