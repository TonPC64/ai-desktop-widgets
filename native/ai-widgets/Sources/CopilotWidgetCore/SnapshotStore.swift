import Foundation

public struct SnapshotStore: Sendable {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func save(_ snapshot: CopilotUsageSnapshot) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }

    public func load() throws -> CopilotUsageSnapshot {
        try JSONDecoder().decode(CopilotUsageSnapshot.self, from: Data(contentsOf: url))
    }
}

public enum CopilotWidgetPaths {
    public static let widgetKind = "com.ai-desktop-widgets.ai-widgets"
    public static let widgetBundleIdentifier = "com.ai-desktop-widgets.ai-widgets.widget"

    public static func hostSnapshotURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectory
            .appending(path: "Library/Containers/\(widgetBundleIdentifier)/Data/Library/Application Support")
            .appending(path: "AIWidgets/snapshot.json")
    }

    public static func extensionSnapshotURL(
        applicationSupportDirectory: URL? = nil
    ) -> URL {
        let directory = applicationSupportDirectory ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
        return directory.appending(path: "AIWidgets/snapshot.json")
    }
}
