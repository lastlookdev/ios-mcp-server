import Foundation

struct BridgeConfig: Sendable {
    let projectPath: String
    let scheme: String
    let testIdentifier: String
    let isWorkspace: Bool

    init(projectPath: String, scheme: String, testIdentifier: String, isWorkspace: Bool = false) {
        self.projectPath = projectPath
        self.scheme = scheme
        self.testIdentifier = testIdentifier
        self.isWorkspace = isWorkspace
    }
}

actor XCUITestBridge {

    init() {}

    private static let bridgeDir = "/tmp/xcuitest-bridge"
    private static let commandFile = "/tmp/xcuitest-bridge/command.json"
    private static let responseFile = "/tmp/xcuitest-bridge/response.json"
    private static let pollIntervalNs: UInt64 = 100_000_000
    private static let responseTimeoutSeconds: TimeInterval = 60
    private static let maxOutputBytes = 1_000_000

    private var process: Process?
    private var _isRunning = false
    private var stderrData = Data()
    private var stdoutData = Data()

    var isRunning: Bool { _isRunning }

    func start(deviceName: String, bundleId: String, config: BridgeConfig) async throws {
        let fm = FileManager.default

        try fm.createDirectory(atPath: Self.bridgeDir, withIntermediateDirectories: true)

        try? fm.removeItem(atPath: Self.commandFile)
        try? fm.removeItem(atPath: Self.responseFile)

        let configData = try JSONSerialization.data(withJSONObject: ["bundleId": bundleId])
        try configData.write(to: URL(fileURLWithPath: Self.bridgeDir + "/config.json"))

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        proc.arguments = [
            "test",
            config.isWorkspace ? "-workspace" : "-project",
            config.projectPath,
            "-scheme", config.scheme,
            "-destination", "platform=iOS Simulator,id=\(deviceName)",
            "-only-testing:\(config.testIdentifier)",
            "-parallel-testing-enabled", "NO",
            "-disable-concurrent-destination-testing",
        ]

        var env = ProcessInfo.processInfo.environment
        env["TARGET_BUNDLE_ID"] = bundleId
        proc.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe
        proc.standardInput = FileHandle.nullDevice

        stderrData = Data()
        stdoutData = Data()

        stdoutPipe.fileHandleForReading.readabilityHandler = { [self] handle in
            let data = handle.availableData
            Task { await self.appendStdout(data) }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { [self] handle in
            let data = handle.availableData
            Task { await self.appendStderr(data) }
        }

        proc.terminationHandler = { [self] _ in
            Task { await self.markStopped() }
        }

        try proc.run()
        process = proc
        _isRunning = true

        let readyFile = Self.bridgeDir + "/ready"
        let deadline = Date().addingTimeInterval(120)

        while Date() < deadline {
            if fm.fileExists(atPath: readyFile) {
                try? fm.removeItem(atPath: readyFile)
                return
            }
            if !_isRunning {
                let output = getProcessOutput()
                throw SimctlError.commandFailed("XCUITest bridge process exited unexpectedly:\n\(output)")
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        throw SimctlError.commandFailed("Timed out waiting for XCUITest bridge to start. Output:\n\(getProcessOutput())")
    }

    func sendCommand(_ command: [String: Any]) async throws -> [String: Any] {
        guard _isRunning else {
            throw SimctlError.commandFailed("XCUITest bridge is not running. The test runner may have crashed or the simulator was closed. Use ui_start_bridge to restart.")
        }

        let id = UUID().uuidString
        var fullCommand = command
        fullCommand["id"] = id

        let data = try JSONSerialization.data(withJSONObject: fullCommand)
        try data.write(to: URL(fileURLWithPath: Self.commandFile))

        let deadline = Date().addingTimeInterval(Self.responseTimeoutSeconds)
        let fm = FileManager.default

        while Date() < deadline {
            if !_isRunning {
                let cmdName = command["command"] as? String ?? "unknown"
                throw SimctlError.commandFailed("Bridge process exited while executing command: \(cmdName). Use ui_start_bridge to restart.")
            }

            if fm.fileExists(atPath: Self.responseFile) {
                let responseData = try Data(contentsOf: URL(fileURLWithPath: Self.responseFile))
                try? fm.removeItem(atPath: Self.responseFile)

                guard let response = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                      response["id"] as? String == id else {
                    continue
                }
                return response
            }
            try await Task.sleep(nanoseconds: Self.pollIntervalNs)
        }

        let cmdName = command["command"] as? String ?? "unknown"
        throw SimctlError.commandFailed("Timed out waiting for bridge response to command: \(cmdName). The bridge may be unresponsive.")
    }

    func stop() async {
        if let proc = process {
            let pid = proc.processIdentifier
            if _isRunning {
                _ = try? await sendCommand(["command": "quit", "params": [String: Any]()])
            }
            if pid > 0 {
                await killChildProcesses(of: pid)
            }
            proc.terminate()
            await proc.waitUntilExitAsync()
        }
        process = nil
        _isRunning = false

        let fm = FileManager.default
        try? fm.removeItem(atPath: Self.commandFile)
        try? fm.removeItem(atPath: Self.responseFile)
    }

    private func killChildProcesses(of pid: Int32) async {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        proc.arguments = ["-P", "\(pid)"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        await proc.waitUntilExitAsync()
    }

    // MARK: - Private

    private func appendStdout(_ data: Data) {
        stdoutData.append(data)
        if stdoutData.count > Self.maxOutputBytes {
            stdoutData = stdoutData.suffix(Self.maxOutputBytes / 2)
        }
    }

    private func appendStderr(_ data: Data) {
        stderrData.append(data)
        if stderrData.count > Self.maxOutputBytes {
            stderrData = stderrData.suffix(Self.maxOutputBytes / 2)
        }
    }

    private func markStopped() { _isRunning = false; process = nil }

    private func getProcessOutput() -> String {
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let combined = stderr.isEmpty ? stdout : stderr
        return String(combined.suffix(2000))
    }
}
