import Foundation

public struct SnapshotStore: Sendable {
    private let url: URL
    private let applicationSupportDirectory: URL

    public init(url: URL) {
        self.url = url
        self.applicationSupportDirectory = url.deletingLastPathComponent()
    }

    public init(applicationSupportDirectory: URL) {
        self.applicationSupportDirectory = applicationSupportDirectory
        self.url = applicationSupportDirectory.appending(path: "snapshot.json")
    }

    public func save(_ snapshot: CopilotUsageSnapshot) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }

    public func load() throws -> CopilotUsageSnapshot {
        try JSONDecoder().decode(CopilotUsageSnapshot.self, from: Data(contentsOf: url))
    }

    public func save(_ snapshot: AIProviderSnapshot, provider: AIProvider) throws {
        let destination = Self.providerURL(provider: provider, applicationSupportDirectory: applicationSupportDirectory)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: destination, options: .atomic)
    }

    public func load(provider: AIProvider) throws -> AIProviderSnapshot {
        let destination = Self.providerURL(provider: provider, applicationSupportDirectory: applicationSupportDirectory)
        return try JSONDecoder().decode(AIProviderSnapshot.self, from: Data(contentsOf: destination))
    }

    public static func providerURL(provider: AIProvider, applicationSupportDirectory: URL) -> URL {
        applicationSupportDirectory.appending(path: "AIWidgets").appending(path: "\(provider.rawValue).json")
    }
}

public enum CopilotWidgetPaths {
    public static let widgetKind = "com.ai-desktop-widgets.ai-widgets.v3"
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

    public static func hostApplicationSupportDirectory(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectory
            .appending(path: "Library/Containers/\(widgetBundleIdentifier)/Data/Library/Application Support")
    }

    public static func extensionApplicationSupportDirectory(
        applicationSupportDirectory: URL? = nil
    ) -> URL {
        applicationSupportDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
    }
}
