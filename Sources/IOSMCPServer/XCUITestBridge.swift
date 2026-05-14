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
    private static let configFile = "/tmp/xcuitest-bridge/config.json"
    private static let readyFile = "/tmp/xcuitest-bridge/ready"
    private static let pollIntervalNs: UInt64 = 100_000_000
    private static let responseTimeoutSeconds: TimeInterval = 60
    private static let maxOutputBytes = 1_000_000

    private var process: Process?
    private var _isRunning = false
    private var _isReady = false
    private var commandInFlight = false
    private var stderrData = Data()
    private var stdoutData = Data()

    var isRunning: Bool { _isRunning }

    func start(deviceName: String, bundleId: String, config: BridgeConfig) async throws {
        guard !_isRunning else {
            throw SimctlError.commandFailed("XCUITest bridge is already running. Stop it first with ui_stop_bridge.")
        }

        let fm = FileManager.default

        try fm.createDirectory(atPath: Self.bridgeDir, withIntermediateDirectories: true)
        removeBridgeFiles()

        let configData = try JSONSerialization.data(withJSONObject: ["bundleId": bundleId])
        try configData.write(to: URL(fileURLWithPath: Self.configFile))

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
        proc.environment = processEnvironment(overrides: env)

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

        do {
            try proc.run()
        } catch {
            removeBridgeFiles()
            throw error
        }
        process = proc
        _isRunning = true
        _isReady = false

        let deadline = Date().addingTimeInterval(120)

        while Date() < deadline {
            if fm.fileExists(atPath: Self.readyFile) {
                try? fm.removeItem(atPath: Self.readyFile)
                _isReady = true
                return
            }
            if !_isRunning {
                let output = getProcessOutput()
                await finishProcess(proc)
                removeBridgeFiles()
                throw SimctlError.commandFailed("XCUITest bridge process exited unexpectedly:\n\(output)")
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        let output = getProcessOutput()
        await finishProcess(proc)
        removeBridgeFiles()
        throw SimctlError.commandFailed("Timed out waiting for XCUITest bridge to start. Output:\n\(output)")
    }

    func sendCommand(_ command: [String: Any]) async throws -> [String: Any] {
        guard _isRunning, _isReady else {
            throw SimctlError.commandFailed("XCUITest bridge is not ready. The test runner may still be starting, may have crashed, or the simulator was closed. Use ui_start_bridge to restart.")
        }

        try await waitForCommandTurn()
        defer { commandInFlight = false }

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
            if _isRunning, _isReady {
                _ = try? await sendCommand(["command": "quit", "params": [String: Any]()])
            }
            await finishProcess(proc)
        }
        process = nil
        _isRunning = false
        _isReady = false
        commandInFlight = false

        removeBridgeFiles()
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

    private func markStopped() {
        _isRunning = false
        _isReady = false
        process = nil
        commandInFlight = false
    }

    private func waitForCommandTurn() async throws {
        while commandInFlight {
            guard _isRunning, _isReady else {
                throw SimctlError.commandFailed("XCUITest bridge stopped while waiting to send a command. Use ui_start_bridge to restart.")
            }
            try await Task.sleep(nanoseconds: Self.pollIntervalNs)
        }
        commandInFlight = true
    }

    private func finishProcess(_ proc: Process) async {
        proc.terminationHandler = nil
        (proc.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        (proc.standardError as? Pipe)?.fileHandleForReading.readabilityHandler = nil

        if process === proc {
            process = nil
        }
        _isRunning = false
        _isReady = false
        commandInFlight = false

        if proc.isRunning {
            let pid = proc.processIdentifier
            if pid > 0 {
                await killChildProcesses(of: pid)
            }
            proc.terminate()
            await proc.waitUntilExitAsync()
        }
    }

    private func removeBridgeFiles() {
        let fm = FileManager.default
        for path in [Self.commandFile, Self.responseFile, Self.configFile, Self.readyFile] {
            try? fm.removeItem(atPath: path)
        }
    }

    private func getProcessOutput() -> String {
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let combined = stderr.isEmpty ? stdout : stderr
        return String(combined.suffix(2000))
    }
}
