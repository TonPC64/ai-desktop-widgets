import AppIntents
#if canImport(CopilotWidgetCore)
import CopilotWidgetCore
#endif

struct ProviderConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "AI provider"
    static let description = IntentDescription("Choose which AI assistant this widget displays.")

    @Parameter(title: "Provider", optionsProvider: ProviderOptionsProvider())
    var provider: String?
}

private struct ProviderOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        AIProvider.allCases.map(\.displayName)
    }
}
