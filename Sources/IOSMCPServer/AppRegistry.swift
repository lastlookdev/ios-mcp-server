import Foundation

package struct SavedCustomRunner: Codable, Equatable, Sendable {
    package let projectPath: String
    package let scheme: String
    package let testIdentifier: String
    package let isWorkspace: Bool

    package init(
        projectPath: String,
        scheme: String,
        testIdentifier: String,
        isWorkspace: Bool = false
    ) {
        self.projectPath = projectPath
        self.scheme = scheme
        self.testIdentifier = testIdentifier
        self.isWorkspace = isWorkspace
    }

    var bridgeConfig: BridgeConfig {
        BridgeConfig(
            projectPath: projectPath,
            scheme: scheme,
            testIdentifier: testIdentifier,
            isWorkspace: isWorkspace
        )
    }
}

package struct SavedAppBuild: Codable, Equatable, Sendable {
    package let projectPath: String
    package let scheme: String
    package let isWorkspace: Bool

    package init(projectPath: String, scheme: String, isWorkspace: Bool = false) {
        self.projectPath = projectPath
        self.scheme = scheme
        self.isWorkspace = isWorkspace
    }
}

package struct SavedAppConfiguration: Codable, Equatable, Sendable {
    package let app: SavedAppBuild?
    package let runner: SavedCustomRunner?

    package init(app: SavedAppBuild? = nil, runner: SavedCustomRunner? = nil) {
        self.app = app
        self.runner = runner
    }
}

package final class AppRegistry {
    private struct Store: Codable {
        var version = 1
        var apps: [String: SavedAppConfiguration] = [:]
    }

    private let fileURL: URL

    package init(fileURL: URL = AppRegistry.defaultFileURL()) {
        self.fileURL = fileURL
    }

    package static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("IOSMCP", isDirectory: true)
            .appendingPathComponent("app-configs.json")
    }

    package func configuration(for bundleId: String) throws -> SavedAppConfiguration? {
        try loadStore().apps[bundleId]
    }

    package func set(_ configuration: SavedAppConfiguration, for bundleId: String) throws {
        var store = try loadStore()
        store.apps[bundleId] = configuration
        try saveStore(store)
    }

    @discardableResult
    package func remove(bundleId: String) throws -> Bool {
        var store = try loadStore()
        let removed = store.apps.removeValue(forKey: bundleId) != nil
        try saveStore(store)
        return removed
    }

    package func list() throws -> [(bundleId: String, configuration: SavedAppConfiguration)] {
        try loadStore().apps
            .map { (bundleId: $0.key, configuration: $0.value) }
            .sorted { $0.bundleId < $1.bundleId }
    }

    private func loadStore() throws -> Store {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return Store()
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(Store.self, from: data)
    }

    private func saveStore(_ store: Store) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(store)
        try data.write(to: fileURL, options: .atomic)
    }
}
