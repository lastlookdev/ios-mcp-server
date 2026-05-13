import Foundation
import Testing
@testable import IOSMCPServer

@Suite("App Registry")
struct AppRegistryTests {

    @Test("Saved app configs round-trip by bundle ID")
    func appConfigRoundTrip() throws {
        let registry = AppRegistry(fileURL: temporaryRegistryURL())
        let config = SavedAppConfiguration(
            app: SavedAppBuild(
                projectPath: "/tmp/MyApp.xcodeproj",
                scheme: "MyApp"
            ),
            runner: SavedCustomRunner(
                projectPath: "/tmp/MyApp.xcodeproj",
                scheme: "MyAppUITests",
                testIdentifier: "MyAppUITests/MyBridgeTests/testBridge"
            )
        )

        try registry.set(config, for: "com.example.App")

        #expect(try registry.configuration(for: "com.example.App") == config)
        #expect(try registry.configuration(for: "com.example.Other") == nil)
    }

    @Test("App configs can be listed and removed")
    func appConfigListAndRemove() throws {
        let registry = AppRegistry(fileURL: temporaryRegistryURL())
        try registry.set(
            SavedAppConfiguration(
                app: SavedAppBuild(
                    projectPath: "/tmp/MyApp.xcodeproj",
                    scheme: "MyApp"
                )
            ),
            for: "com.example.App"
        )

        #expect(try registry.list().map(\.bundleId) == ["com.example.App"])
        #expect(try registry.remove(bundleId: "com.example.App"))
        #expect(try registry.list().isEmpty)
        #expect(!(try registry.remove(bundleId: "com.example.App")))
    }

    private func temporaryRegistryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("app-configs.json")
    }
}
