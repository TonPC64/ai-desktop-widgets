import CopilotWidgetCore
import Foundation
import ServiceManagement
import WidgetKit

@main
enum CopilotWidgetHost {
    static func main() {
        try? SMAppService.mainApp.register()
        refresh()
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in refresh() }
        RunLoop.main.run()
    }

    private static func refresh() {
        let store = SnapshotStore(applicationSupportDirectory: CopilotWidgetPaths.hostApplicationSupportDirectory())
        for collector in collectors() {
            do {
                let data = try run(collector)
                let snapshot = try ProviderPayload.decode(provider: collector.provider, data: data, observedAt: .now)
                try store.save(snapshot, provider: collector.provider)
            } catch {
                continue
            }
        }
        WidgetCenter.shared.reloadTimelines(ofKind: CopilotWidgetPaths.widgetKind)
    }

    private struct Collector {
        let provider: AIProvider
        let path: String
        let arguments: [String]
    }

    private static func collectors() -> [Collector] {
        let resource = Bundle.main.resourceURL
        return [
            .init(provider: .copilot, path: ProcessInfo.processInfo.environment["COPILOT_WIDGET_COLLECTOR"] ?? resource?.appending(path: "scripts/copilot-data.sh").path ?? "", arguments: []),
            .init(provider: .claude, path: resource?.appending(path: "scripts/claude-status.sh").path ?? "", arguments: ["graph", "native-graph"]),
            .init(provider: .codex, path: resource?.appending(path: "scripts/codex-data.sh").path ?? "", arguments: [])
        ]
    }

    private static func run(_ collector: Collector) throws -> Data {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(filePath: "/bin/bash")
        process.arguments = [collector.path] + collector.arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CocoaError(.fileReadUnknown) }
        return output.fileHandleForReading.readDataToEndOfFile()
    }
}
