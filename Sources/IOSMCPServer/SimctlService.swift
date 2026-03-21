import Foundation

struct SimDevice: Sendable {
    let name: String
    let udid: String
    let state: String
    let runtime: String
    let isAvailable: Bool
}

struct StatusBarOverrides: Sendable {
    var time: String?
    var batteryLevel: Int?
    var batteryState: String?
    var cellularBars: Int?
    var wifiBars: Int?
    var operatorName: String?
}

enum SimctlError: Error, LocalizedError {
    case deviceNotFound(String)
    case deviceNotBooted(String)
    case appNotInstalled(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .deviceNotFound(let msg): return "Device not found: \(msg)"
        case .deviceNotBooted(let msg): return "Device not booted: \(msg)"
        case .appNotInstalled(let msg): return "App not installed: \(msg)"
        case .commandFailed(let msg): return "simctl error: \(msg)"
        }
    }
}

actor SimctlService {

    init() {}

    private func simctl(_ args: [String], timeout: TimeInterval = 30) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + args

        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe

        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        if process.isRunning {
            process.terminate()
            throw SimctlError.commandFailed("Command timed out: simctl \(args.joined(separator: " "))")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw classifyError(command: args.joined(separator: " "), stderr: stderr)
        }

        return output
    }

    private func classifyError(command: String, stderr: String) -> SimctlError {
        let lower = stderr.lowercased()
        if lower.contains("invalid device") || lower.contains("no devices found") {
            return .deviceNotFound(stderr)
        }
        if lower.contains("not booted") || lower.contains("device is not booted") {
            return .deviceNotBooted(stderr)
        }
        if lower.contains("not installed") {
            return .appNotInstalled(stderr)
        }
        return .commandFailed(stderr)
    }

    // MARK: - Device Management

    func listDevices() async throws -> [SimDevice] {
        let output = try await simctl(["list", "devices", "-j"])
        guard let data = output.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = json["devices"] as? [String: [[String: Any]]] else {
            return []
        }

        var result: [SimDevice] = []
        for (runtime, deviceList) in devices {
            let cleanRuntime = runtime.replacingOccurrences(
                of: "com.apple.CoreSimulator.SimRuntime.",
                with: ""
            )
            for device in deviceList {
                result.append(SimDevice(
                    name: device["name"] as? String ?? "",
                    udid: device["udid"] as? String ?? "",
                    state: device["state"] as? String ?? "",
                    runtime: cleanRuntime,
                    isAvailable: device["isAvailable"] as? Bool ?? false
                ))
            }
        }
        return result
    }

    func resolveDevice(_ nameOrUdid: String) async throws -> String {
        let uuidPattern = #"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$"#
        if nameOrUdid.range(of: uuidPattern, options: [.regularExpression, .caseInsensitive]) != nil {
            return nameOrUdid
        }

        let devices = try await listDevices()
        guard let match = devices.first(where: { $0.name == nameOrUdid && $0.isAvailable }) else {
            throw SimctlError.deviceNotFound("No available device named \"\(nameOrUdid)\"")
        }
        return match.udid
    }

    func bootDevice(_ nameOrUdid: String) async throws -> String {
        let udid = try await resolveDevice(nameOrUdid)

        let devices = try await listDevices()
        if devices.first(where: { $0.udid == udid })?.state == "Booted" {
            return udid
        }

        _ = try await simctl(["boot", udid])
        _ = try await simctl(["bootstatus", udid, "-b"], timeout: 120)

        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-a", "Simulator"]
        try open.run()
        await open.waitUntilExitAsync()

        return udid
    }

    func shutdownDevice(_ nameOrUdid: String) async throws {
        let udid = try await resolveDevice(nameOrUdid)
        _ = try await simctl(["shutdown", udid])
    }

    // MARK: - App Management

    func installApp(deviceUdid: String, appPath: String) async throws {
        _ = try await simctl(["install", deviceUdid, appPath], timeout: 60)
    }

    func launchApp(deviceUdid: String, bundleId: String) async throws {
        _ = try await simctl(["launch", deviceUdid, bundleId])
    }

    func uninstallApp(deviceUdid: String, bundleId: String) async throws {
        _ = try await simctl(["uninstall", deviceUdid, bundleId])
    }

    func eraseDevice(_ nameOrUdid: String) async throws {
        let udid = try await resolveDevice(nameOrUdid)
        _ = try await simctl(["erase", udid])
    }

    // MARK: - Privacy

    func setPrivacy(deviceUdid: String, action: String, service: String, bundleId: String) async throws {
        _ = try await simctl(["privacy", deviceUdid, action, service, bundleId])
    }

    // MARK: - Keychain

    func addRootCertificate(deviceUdid: String, certPath: String) async throws {
        _ = try await simctl(["keychain", deviceUdid, "add-root-cert", certPath])
    }

    func resetKeychain(deviceUdid: String) async throws {
        _ = try await simctl(["keychain", deviceUdid, "reset"])
    }

    // MARK: - Video Recording

    private var recordingProcess: Process?

    func startRecording(deviceUdid: String, path: String) async throws {
        let dir = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "io", deviceUdid, "recordVideo", "--codec=h264", path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        recordingProcess = process
    }

    func stopRecording() async {
        recordingProcess?.interrupt()
        await recordingProcess?.waitUntilExitAsync()
        recordingProcess = nil
    }

    // MARK: - App Container

    func getAppContainer(deviceUdid: String, bundleId: String, container: String = "app") async throws -> String {
        let output = try await simctl(["get_app_container", deviceUdid, bundleId, container])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Media

    func addMedia(deviceUdid: String, path: String) async throws {
        _ = try await simctl(["addmedia", deviceUdid, path])
    }

    // MARK: - Biometrics

    func enrollBiometric(deviceUdid: String) async throws {
        _ = try await simctl(["spawn", deviceUdid, "notifyutil", "-s", "com.apple.BiometricKit.enrollmentChanged", "1"])
        _ = try await simctl(["spawn", deviceUdid, "notifyutil", "-p", "com.apple.BiometricKit.enrollmentChanged"])
    }

    func matchBiometric(deviceUdid: String) async throws {
        _ = try await simctl(["spawn", deviceUdid, "notifyutil", "-p", "com.apple.BiometricKit_Sim.fingerTouch.match"])
    }

    func failBiometric(deviceUdid: String) async throws {
        _ = try await simctl(["spawn", deviceUdid, "notifyutil", "-p", "com.apple.BiometricKit_Sim.fingerTouch.nomatch"])
    }

    // MARK: - Screenshot

    func takeScreenshot(deviceUdid: String, savePath: String? = nil) async throws -> String {
        let filePath = savePath ?? NSTemporaryDirectory() + "screenshot-\(UUID().uuidString).png"

        let dir = (filePath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        _ = try await simctl(["io", deviceUdid, "screenshot", "--type=png", filePath], timeout: 15)
        return filePath
    }

    // MARK: - Appearance & Locale

    func setAppearance(deviceUdid: String, mode: String) async throws {
        _ = try await simctl(["ui", deviceUdid, "appearance", mode])
    }

    func setLocale(deviceUdid: String, locale: String, language: String) async throws {
        let devices = try await listDevices()
        let wasBooted = devices.first(where: { $0.udid == deviceUdid })?.state == "Booted"

        if wasBooted {
            _ = try await simctl(["shutdown", deviceUdid])
        }

        let prefsPath = NSHomeDirectory() +
            "/Library/Developer/CoreSimulator/Devices/\(deviceUdid)" +
            "/data/Library/Preferences/.GlobalPreferences.plist"

        let plutil1 = Process()
        plutil1.executableURL = URL(fileURLWithPath: "/usr/bin/plutil")
        plutil1.arguments = ["-replace", "AppleLocale", "-string", locale, prefsPath]
        try plutil1.run()
        await plutil1.waitUntilExitAsync()

        let langJson = try JSONSerialization.data(withJSONObject: [language])
        let langStr = String(data: langJson, encoding: .utf8) ?? "[\"\(language)\"]"

        let plutil2 = Process()
        plutil2.executableURL = URL(fileURLWithPath: "/usr/bin/plutil")
        plutil2.arguments = ["-replace", "AppleLanguages", "-json", langStr, prefsPath]
        try plutil2.run()
        await plutil2.waitUntilExitAsync()

        _ = try await simctl(["boot", deviceUdid])
        _ = try await simctl(["bootstatus", deviceUdid, "-b"], timeout: 120)
    }

    // MARK: - Status Bar

    func clearStatusBar(deviceUdid: String) async throws {
        _ = try await simctl(["status_bar", deviceUdid, "clear"])
    }

    func setStatusBar(deviceUdid: String, overrides: StatusBarOverrides) async throws {
        var args = ["status_bar", deviceUdid, "override"]

        if let time = overrides.time { args += ["--time", time] }
        if let level = overrides.batteryLevel { args += ["--batteryLevel", String(level)] }
        if let state = overrides.batteryState { args += ["--batteryState", state] }
        if let bars = overrides.cellularBars { args += ["--cellularBars", String(bars)] }
        if let wifi = overrides.wifiBars { args += ["--wifiBars", String(wifi)] }
        if let name = overrides.operatorName { args += ["--operatorName", name] }

        _ = try await simctl(args)
    }

    // MARK: - Logs

    func getLogs(deviceUdid: String, filter: String? = nil, lines: Int = 50) async throws -> String {
        var args = ["spawn", deviceUdid, "log", "show", "--style", "compact"]
        if let filter {
            args += ["--predicate", filter]
        }
        args += ["--last", String(lines)]
        return try await simctl(args, timeout: 15)
    }

    // MARK: - URLs, Push, Location

    func openURL(deviceUdid: String, url: String) async throws {
        _ = try await simctl(["openurl", deviceUdid, url])
    }

    func sendPushNotification(deviceUdid: String, bundleId: String, payload: [String: Any]) async throws {
        let apnsPayload: [String: Any] = ["aps": payload]
        let data = try JSONSerialization.data(withJSONObject: apnsPayload)
        let path = NSTemporaryDirectory() + "push-\(UUID().uuidString).json"
        try data.write(to: URL(fileURLWithPath: path))

        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try await simctl(["push", deviceUdid, bundleId, path])
    }

    func setLocation(deviceUdid: String, lat: Double, lng: Double) async throws {
        _ = try await simctl(["location", deviceUdid, "set", "\(lat),\(lng)"])
    }
}
