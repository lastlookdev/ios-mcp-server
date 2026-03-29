import Foundation

final class RunnerProject {

    static let scheme = "RunnerUITests"
    static let testIdentifier = "RunnerUITests/RunnerUITests/testBridge"
    static let runnerVersion = "1"

    var basePath: String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.path
        return appSupport + "/IOSMCP/Runner"
    }

    var projectPath: String {
        basePath + "/Runner.xcodeproj"
    }

    private var versionFile: String {
        basePath + "/.runner-version"
    }

    init() {}

    func ensureReady() async throws {
        let fm = FileManager.default

        if fm.fileExists(atPath: projectPath + "/project.pbxproj"),
           let versionData = fm.contents(atPath: versionFile),
           String(data: versionData, encoding: .utf8)?
               .trimmingCharacters(in: .whitespacesAndNewlines) == Self.runnerVersion {
            return
        }

        guard let zipURL = Bundle.module.url(forResource: "Runner", withExtension: "zip") else {
            throw SimctlError.commandFailed(
                "Runner.zip not found in bundle. The ios-mcp-server package may not have been built correctly."
            )
        }

        try? fm.removeItem(atPath: basePath)
        try fm.createDirectory(atPath: basePath, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-xk", zipURL.path, basePath]
        process.standardOutput = FileHandle.nullDevice
        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        try process.run()
        await process.waitUntilExitAsync()

        guard process.terminationStatus == 0 else {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrString = String(data: stderrData, encoding: .utf8) ?? ""
            throw SimctlError.commandFailed(
                "Failed to extract Runner.zip (exit \(process.terminationStatus)): \(stderrString)"
            )
        }

        try Self.runnerVersion.write(toFile: versionFile, atomically: true, encoding: .utf8)
    }

    func bridgeConfig() -> BridgeConfig {
        BridgeConfig(
            projectPath: projectPath,
            scheme: Self.scheme,
            testIdentifier: Self.testIdentifier
        )
    }
}
