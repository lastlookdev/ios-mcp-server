import Foundation
import MCP

// MARK: - Schema Builders

func toolSchema(
    properties: [String: Value] = [:],
    required: [String] = []
) -> Value {
    var schema: [String: Value] = ["type": .string("object")]
    if !properties.isEmpty {
        schema["properties"] = .object(properties)
    }
    if !required.isEmpty {
        schema["required"] = .array(required.map { .string($0) })
    }
    return .object(schema)
}

extension Value {
    static func stringProperty(_ description: String) -> Value {
        .object(["type": .string("string"), "description": .string(description)])
    }
    static func numberProperty(_ description: String) -> Value {
        .object(["type": .string("number"), "description": .string(description)])
    }
    static func booleanProperty(_ description: String) -> Value {
        .object(["type": .string("boolean"), "description": .string(description)])
    }
}

// MARK: - Required Parameter Error

struct MissingParameterError: Error, LocalizedError {
    let name: String
    var errorDescription: String? { "Missing required parameter: \(name)" }
}

// MARK: - Argument Extraction

extension Dictionary where Key == String, Value == MCP.Value {
    func require(_ key: String) throws -> String {
        guard let value = string(key), !value.isEmpty else {
            throw MissingParameterError(name: key)
        }
        return value
    }
    func requireDouble(_ key: String) throws -> Double {
        guard let value = double(key) else {
            throw MissingParameterError(name: key)
        }
        return value
    }
    func string(_ key: String) -> String? {
        if case .string(let s) = self[key] { return s }
        return nil
    }
    func int(_ key: String) -> Int? {
        switch self[key] {
        case .int(let n): return n
        case .double(let n): return Int(n)
        default: return nil
        }
    }
    func double(_ key: String) -> Double? {
        switch self[key] {
        case .double(let n): return n
        case .int(let n): return Double(n)
        default: return nil
        }
    }
    func bool(_ key: String) -> Bool? {
        if case .bool(let b) = self[key] { return b }
        return nil
    }
}

// MARK: - JSON Response Helpers

func jsonResponse(_ dict: [String: Any]) throws -> CallTool.Result {
    let data = try JSONSerialization.data(withJSONObject: dict, options: .sortedKeys)
    return .init(content: [.text(String(data: data, encoding: .utf8) ?? "{}")])
}

func successResponse(_ extra: [String: Any] = [:]) throws -> CallTool.Result {
    var dict: [String: Any] = ["success": true]
    for (key, value) in extra { dict[key] = value }
    return try jsonResponse(dict)
}

// MARK: - Async Process Helpers

extension Process {
    func waitUntilExitAsync() async {
        while isRunning {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}

struct ProcessResult: Sendable {
    let status: Int32
    let output: String
}

func processEnvironment(overrides: [String: String] = [:]) -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    for (key, value) in overrides {
        environment[key] = value
    }

    environment["PATH"] = normalizedExecutablePath(environment["PATH"])
    environment["HOME"] = environment["HOME"] ?? NSHomeDirectory()
    environment["USER"] = environment["USER"] ?? NSUserName()
    environment["LOGNAME"] = environment["LOGNAME"] ?? NSUserName()

    if environment["GIT_SSH"].isEmptyOrNil,
       environment["GIT_SSH_COMMAND"].isEmptyOrNil,
       FileManager.default.isExecutableFile(atPath: "/usr/bin/ssh") {
        environment["GIT_SSH_COMMAND"] = "/usr/bin/ssh"
    }

    return environment
}

func runProcess(
    executable: String,
    arguments: [String],
    environment: [String: String]? = nil
) async throws -> ProcessResult {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: executable)
    proc.arguments = arguments
    proc.environment = processEnvironment(overrides: environment ?? [:])
    proc.standardInput = FileHandle.nullDevice

    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = pipe

    async let outputData = pipe.fileHandleForReading.readToEnd()
    try proc.run()
    await proc.waitUntilExitAsync()

    let data = try await outputData ?? Data()
    return ProcessResult(
        status: proc.terminationStatus,
        output: String(data: data, encoding: .utf8) ?? ""
    )
}

struct TimeoutError: Error, LocalizedError {
    let seconds: TimeInterval
    var errorDescription: String? { "Timed out after \(Int(seconds)) seconds" }
}

func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError(seconds: seconds)
        }

        guard let result = try await group.next() else {
            throw TimeoutError(seconds: seconds)
        }
        group.cancelAll()
        return result
    }
}

private func normalizedExecutablePath(_ current: String?) -> String {
    let defaults = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
    var seen: Set<String> = []
    var paths = (current ?? "")
        .split(separator: ":")
        .map(String.init)
        .filter { !$0.isEmpty }

    paths.append(contentsOf: defaults)
    return paths
        .filter { seen.insert($0).inserted }
        .joined(separator: ":")
}

private extension Optional where Wrapped == String {
    var isEmptyOrNil: Bool {
        self?.isEmpty ?? true
    }
}

// MARK: - Bridge Response Helper

func bridgeCommand(
    _ command: String,
    params: [String: Any] = [:],
    bridge: XCUITestBridge
) async throws -> CallTool.Result {
    let response = try await bridge.sendCommand(["command": command, "params": params])
    let data = try JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
    return .init(content: [.text(String(data: data, encoding: .utf8) ?? "{}")])
}
