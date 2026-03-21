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

// MARK: - Argument Extraction

extension Dictionary where Key == String, Value == MCP.Value {
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
