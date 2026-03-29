import Foundation
import MCP

func xcuitestTools() -> [Tool] {
    [
        Tool(
            name: "ui_start_bridge",
            description: "Start the XCUITest bridge for interactive app control. Requires device, bundle_id, and runner project config (project_path, scheme, test_identifier). Optionally provide app_project_path/app_scheme to build and install the app before starting.",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name (e.g. 'iPhone 17 Pro')"),
                    "bundle_id": .stringProperty("Bundle ID of the app to control"),
                    "project_path": .stringProperty("Optional: path to a custom runner .xcodeproj or .xcworkspace"),
                    "scheme": .stringProperty("Optional: custom UI test scheme name"),
                    "test_identifier": .stringProperty("Optional: custom test identifier (e.g. MyUITests/MyUITests/testBridge)"),
                    "app_project_path": .stringProperty("Optional: path to the app's .xcodeproj to build and install before testing"),
                    "app_scheme": .stringProperty("Optional: the app's scheme to build (required if app_project_path is provided)"),
                    "is_workspace": .booleanProperty("Set to true if project_path is a .xcworkspace"),
                ],
                required: ["device", "bundle_id"]
            )
        ),
        Tool(
            name: "ui_tap",
            description: "Tap a UI element in the running app by accessibility identifier or label",
            inputSchema: toolSchema(
                properties: [
                    "identifier": .stringProperty("Accessibility identifier of the element"),
                    "label": .stringProperty("Accessibility label of the element"),
                    "element_type": .stringProperty("Element type (e.g. button, cell)"),
                    "index": .numberProperty("Index of the element"),
                ]
            )
        ),
        Tool(
            name: "ui_type",
            description: "Type text into a text field. Optionally specify which field by identifier.",
            inputSchema: toolSchema(
                properties: [
                    "text": .stringProperty("Text to type"),
                    "field_identifier": .stringProperty("Accessibility identifier of the text field"),
                ],
                required: ["text"]
            )
        ),
        Tool(
            name: "ui_swipe",
            description: "Swipe in a direction on the screen or a specific element",
            inputSchema: toolSchema(
                properties: [
                    "direction": .stringProperty("Swipe direction: up, down, left, right"),
                    "element": .stringProperty("Accessibility identifier of element to swipe on"),
                ],
                required: ["direction"]
            )
        ),
        Tool(
            name: "ui_scroll",
            description: "Scroll within a scrollable element",
            inputSchema: toolSchema(
                properties: [
                    "direction": .stringProperty("Scroll direction: up or down"),
                    "element": .stringProperty("Accessibility identifier of scrollable element"),
                ],
                required: ["direction"]
            )
        ),
        Tool(
            name: "ui_read_screen",
            description: "Read the current screen's accessibility tree to understand what UI elements are displayed",
            inputSchema: toolSchema(
                properties: [
                    "depth": .numberProperty("Maximum depth to traverse (default 5)"),
                ]
            )
        ),
        Tool(
            name: "ui_wait_for",
            description: "Wait for a specific element to appear on screen",
            inputSchema: toolSchema(
                properties: [
                    "identifier": .stringProperty("Accessibility identifier to wait for"),
                    "label": .stringProperty("Accessibility label to wait for"),
                    "timeout_seconds": .numberProperty("Timeout in seconds (default 10)"),
                ]
            )
        ),
        Tool(
            name: "ui_long_press",
            description: "Long press (press and hold) a UI element",
            inputSchema: toolSchema(
                properties: [
                    "identifier": .stringProperty("Accessibility identifier"),
                    "label": .stringProperty("Accessibility label"),
                    "duration": .numberProperty("Press duration in seconds (default 1.0)"),
                ]
            )
        ),
        Tool(
            name: "ui_double_tap",
            description: "Double tap a UI element (e.g. for text selection or zoom)",
            inputSchema: toolSchema(
                properties: [
                    "identifier": .stringProperty("Accessibility identifier"),
                    "label": .stringProperty("Accessibility label"),
                ]
            )
        ),
        Tool(
            name: "ui_adjust_slider",
            description: "Adjust a slider to a specific position (0.0 to 1.0)",
            inputSchema: toolSchema(
                properties: [
                    "identifier": .stringProperty("Accessibility identifier of the slider"),
                    "value": .numberProperty("Normalized position from 0.0 (min) to 1.0 (max)"),
                ],
                required: ["value"]
            )
        ),
        Tool(
            name: "ui_adjust_picker",
            description: "Select a value in a picker wheel",
            inputSchema: toolSchema(
                properties: [
                    "identifier": .stringProperty("Accessibility identifier of the picker"),
                    "value": .stringProperty("The value to select in the picker wheel"),
                ],
                required: ["value"]
            )
        ),
        Tool(
            name: "ui_pinch",
            description: "Pinch to zoom in or out on the screen or a specific element",
            inputSchema: toolSchema(
                properties: [
                    "identifier": .stringProperty("Accessibility identifier of element to pinch on"),
                    "scale": .numberProperty("Scale factor — >1.0 zooms in, <1.0 zooms out (default 2.0)"),
                    "velocity": .numberProperty("Pinch velocity (default 1.0)"),
                ]
            )
        ),
        Tool(
            name: "ui_drag",
            description: "Drag from one element to another (press, hold, and drag)",
            inputSchema: toolSchema(
                properties: [
                    "from_identifier": .stringProperty("Accessibility identifier of the source element"),
                    "to_identifier": .stringProperty("Accessibility identifier of the target element"),
                    "duration": .numberProperty("Hold duration before dragging (default 0.5)"),
                ],
                required: ["from_identifier", "to_identifier"]
            )
        ),
        Tool(
            name: "ui_element_info",
            description: "Get detailed info about a UI element (exists, enabled, selected, hittable, value, frame)",
            inputSchema: toolSchema(
                properties: [
                    "identifier": .stringProperty("Accessibility identifier"),
                    "label": .stringProperty("Accessibility label"),
                ]
            )
        ),
        Tool(
            name: "ui_element_count",
            description: "Count the number of elements of a given type on screen",
            inputSchema: toolSchema(
                properties: [
                    "element_type": .stringProperty("Element type: button, text, cell, image, textField, switch, slider, etc."),
                    "identifier": .stringProperty("Filter by identifier"),
                    "label": .stringProperty("Filter by label"),
                ],
                required: ["element_type"]
            )
        ),
        Tool(
            name: "ui_dismiss_keyboard",
            description: "Dismiss the on-screen keyboard",
            inputSchema: toolSchema()
        ),
        Tool(
            name: "ui_dismiss_modal",
            description: "Dismiss any visible modal (alert, sheet, popover, or context menu) using common dismissal strategies",
            inputSchema: toolSchema()
        ),
        Tool(
            name: "ui_stop_bridge",
            description: "Stop the XCUITest bridge",
            inputSchema: toolSchema()
        ),
    ]
}

func handleXCUITestTool(
    name: String,
    args: [String: Value]?,
    bridge: XCUITestBridge,
    simctl: SimctlService
) async throws -> CallTool.Result {
    switch name {
    case "ui_start_bridge":
        let isRunning = await bridge.isRunning
        if isRunning {
            return try jsonResponse(["success": false, "message": "Bridge is already running. Stop it first with ui_stop_bridge."])
        }

        let device = args?.string("device") ?? ""
        let bundleId = args?.string("bundle_id") ?? ""
        let isWorkspace = args?.bool("is_workspace") ?? false

        let deviceUdid = try await simctl.bootDevice(device)

        if let appProject = args?.string("app_project_path"), !appProject.isEmpty,
           let appScheme = args?.string("app_scheme"), !appScheme.isEmpty {
            try await buildAndInstallApp(
                project: appProject,
                scheme: appScheme,
                isWorkspace: isWorkspace,
                deviceUdid: deviceUdid,
                simctl: simctl
            )
        }

        let config: BridgeConfig
        let customPath = args?.string("project_path")
        let customScheme = args?.string("scheme")
        let customTest = args?.string("test_identifier")

        if let path = customPath, !path.isEmpty,
           let scheme = customScheme, !scheme.isEmpty,
           let test = customTest, !test.isEmpty {
            config = BridgeConfig(
                projectPath: path,
                scheme: scheme,
                testIdentifier: test,
                isWorkspace: isWorkspace
            )
        } else {
            let runner = RunnerProject()
            try await runner.ensureReady()
            config = runner.bridgeConfig()
        }

        try await bridge.start(deviceName: deviceUdid, bundleId: bundleId, config: config)
        return try successResponse(["message": "Bridge started for \(bundleId) on \(device)"])

    case "ui_tap":
        var params: [String: Any] = [:]
        if let id = args?.string("identifier") { params["identifier"] = id }
        if let label = args?.string("label") { params["label"] = label }
        if let type = args?.string("element_type") { params["elementType"] = type }
        if let index = args?.int("index") { params["index"] = index }
        return try await bridgeCommand("tap", params: params, bridge: bridge)

    case "ui_type":
        var params: [String: Any] = ["text": args?.string("text") ?? ""]
        if let fieldId = args?.string("field_identifier") { params["identifier"] = fieldId }
        return try await bridgeCommand("type", params: params, bridge: bridge)

    case "ui_swipe":
        var params: [String: Any] = ["direction": args?.string("direction") ?? ""]
        if let element = args?.string("element") { params["element"] = element }
        return try await bridgeCommand("swipe", params: params, bridge: bridge)

    case "ui_scroll":
        var params: [String: Any] = ["direction": args?.string("direction") ?? ""]
        if let element = args?.string("element") { params["element"] = element }
        return try await bridgeCommand("scroll", params: params, bridge: bridge)

    case "ui_read_screen":
        var params: [String: Any] = [:]
        if let depth = args?.int("depth") { params["depth"] = depth }
        let response = try await bridge.sendCommand(["command": "read_tree", "params": params])
        let payload = response["data"] as? [String: Any] ?? response
        let data = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
        return .init(content: [.text(String(data: data, encoding: .utf8) ?? "{}")])

    case "ui_wait_for":
        var params: [String: Any] = [:]
        if let id = args?.string("identifier") { params["identifier"] = id }
        if let label = args?.string("label") { params["label"] = label }
        params["timeout"] = args?.int("timeout_seconds") ?? 10
        return try await bridgeCommand("wait_for", params: params, bridge: bridge)

    case "ui_long_press":
        var params: [String: Any] = [:]
        if let id = args?.string("identifier") { params["identifier"] = id }
        if let label = args?.string("label") { params["label"] = label }
        if let duration = args?.double("duration") { params["duration"] = duration }
        return try await bridgeCommand("long_press", params: params, bridge: bridge)

    case "ui_double_tap":
        var params: [String: Any] = [:]
        if let id = args?.string("identifier") { params["identifier"] = id }
        if let label = args?.string("label") { params["label"] = label }
        return try await bridgeCommand("double_tap", params: params, bridge: bridge)

    case "ui_adjust_slider":
        var params: [String: Any] = [:]
        if let id = args?.string("identifier") { params["identifier"] = id }
        if let value = args?.double("value") { params["value"] = value }
        return try await bridgeCommand("adjust_slider", params: params, bridge: bridge)

    case "ui_adjust_picker":
        var params: [String: Any] = [:]
        if let id = args?.string("identifier") { params["identifier"] = id }
        if let value = args?.string("value") { params["value"] = value }
        return try await bridgeCommand("adjust_picker", params: params, bridge: bridge)

    case "ui_pinch":
        var params: [String: Any] = [:]
        if let id = args?.string("identifier") { params["identifier"] = id }
        if let scale = args?.double("scale") { params["scale"] = scale }
        if let velocity = args?.double("velocity") { params["velocity"] = velocity }
        return try await bridgeCommand("pinch", params: params, bridge: bridge)

    case "ui_drag":
        var params: [String: Any] = [:]
        if let from = args?.string("from_identifier") { params["from_identifier"] = from }
        if let to = args?.string("to_identifier") { params["to_identifier"] = to }
        if let duration = args?.double("duration") { params["duration"] = duration }
        return try await bridgeCommand("drag", params: params, bridge: bridge)

    case "ui_element_info":
        var params: [String: Any] = [:]
        if let id = args?.string("identifier") { params["identifier"] = id }
        if let label = args?.string("label") { params["label"] = label }
        return try await bridgeCommand("element_info", params: params, bridge: bridge)

    case "ui_element_count":
        var params: [String: Any] = [:]
        if let type = args?.string("element_type") { params["element_type"] = type }
        if let id = args?.string("identifier") { params["identifier"] = id }
        if let label = args?.string("label") { params["label"] = label }
        return try await bridgeCommand("element_count", params: params, bridge: bridge)

    case "ui_dismiss_keyboard":
        return try await bridgeCommand("dismiss_keyboard", bridge: bridge)

    case "ui_dismiss_modal":
        return try await bridgeCommand("dismiss_modal", bridge: bridge)

    case "ui_stop_bridge":
        await bridge.stop()
        return try successResponse()

    default:
        return .init(content: [.text("Unknown tool: \(name)")], isError: true)
    }
}

// MARK: - App Build Helper

private func buildAndInstallApp(
    project: String,
    scheme: String,
    isWorkspace: Bool,
    deviceUdid: String,
    simctl: SimctlService
) async throws {
    let buildProc = Process()
    buildProc.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
    buildProc.arguments = [
        "build",
        isWorkspace ? "-workspace" : "-project", project,
        "-scheme", scheme,
        "-sdk", "iphonesimulator",
        "-destination", "platform=iOS Simulator,id=\(deviceUdid)",
        "-quiet",
    ]
    let buildPipe = Pipe()
    buildProc.standardOutput = buildPipe
    buildProc.standardError = buildPipe
    buildProc.standardInput = FileHandle.nullDevice
    try buildProc.run()
    await buildProc.waitUntilExitAsync()

    if buildProc.terminationStatus != 0 {
        let output = String(data: buildPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let lastLines = output.split(separator: "\n").suffix(10).joined(separator: "\n")
        throw SimctlError.commandFailed("Failed to build app:\n\(lastLines)")
    }

    let settingsProc = Process()
    settingsProc.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
    settingsProc.arguments = [
        isWorkspace ? "-workspace" : "-project", project,
        "-scheme", scheme,
        "-sdk", "iphonesimulator",
        "-showBuildSettings",
    ]
    let settingsPipe = Pipe()
    settingsProc.standardOutput = settingsPipe
    settingsProc.standardError = FileHandle.nullDevice
    settingsProc.standardInput = FileHandle.nullDevice
    try settingsProc.run()
    await settingsProc.waitUntilExitAsync()

    let settingsOutput = String(data: settingsPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    var builtProductsDir = ""
    var productName = ""
    for line in settingsOutput.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("BUILT_PRODUCTS_DIR = ") {
            builtProductsDir = String(trimmed.dropFirst("BUILT_PRODUCTS_DIR = ".count))
        } else if trimmed.hasPrefix("FULL_PRODUCT_NAME = ") {
            productName = String(trimmed.dropFirst("FULL_PRODUCT_NAME = ".count))
        }
    }

    if !builtProductsDir.isEmpty && !productName.isEmpty {
        let appPath = builtProductsDir + "/" + productName
        if FileManager.default.fileExists(atPath: appPath) {
            try await simctl.installApp(deviceUdid: deviceUdid, appPath: appPath)
        }
    }
}
