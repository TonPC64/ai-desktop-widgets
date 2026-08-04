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
        guard let collectorURL = collectorURL() else { return }
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(filePath: "/bin/bash")
        process.arguments = [collectorURL.path]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return }
            let snapshot = try CollectorPayload.decode(output.fileHandleForReading.readDataToEndOfFile(), observedAt: .now)
            try SnapshotStore(url: CopilotWidgetPaths.hostSnapshotURL()).save(snapshot)
            WidgetCenter.shared.reloadTimelines(ofKind: CopilotWidgetPaths.widgetKind)
        } catch {
            return
        }
    }

    private static func collectorURL() -> URL? {
        if let path = ProcessInfo.processInfo.environment["COPILOT_WIDGET_COLLECTOR"] {
            return URL(filePath: path)
        }
        return Bundle.main.resourceURL?.appending(path: "copilot-data.sh")
    }
}
