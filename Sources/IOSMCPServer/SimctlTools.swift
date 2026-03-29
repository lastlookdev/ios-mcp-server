import Foundation
import MCP

func simctlTools() -> [Tool] {
    [
        Tool(
            name: "sim_list_devices",
            description: "List all available iOS simulators and their current state",
            inputSchema: toolSchema()
        ),
        Tool(
            name: "sim_boot",
            description: "Boot an iOS simulator by name or UDID",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                ],
                required: ["device"]
            )
        ),
        Tool(
            name: "sim_shutdown",
            description: "Shutdown a running simulator",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                ],
                required: ["device"]
            )
        ),
        Tool(
            name: "sim_install_app",
            description: "Install an .app bundle on a booted simulator",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                    "app_path": .stringProperty("Path to the .app bundle"),
                ],
                required: ["device", "app_path"]
            )
        ),
        Tool(
            name: "sim_launch_app",
            description: "Launch an app on the simulator",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                    "bundle_id": .stringProperty("App bundle identifier"),
                ],
                required: ["device", "bundle_id"]
            )
        ),
        Tool(
            name: "sim_keychain",
            description: "Manage the simulator keychain — add root certificates or reset",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                    "action": .stringProperty("Action: add-root-cert or reset"),
                    "cert_path": .stringProperty("Path to certificate file (required for add-root-cert)"),
                ],
                required: ["device", "action"]
            )
        ),
        Tool(
            name: "sim_record_video",
            description: "Start or stop recording a video of the simulator screen",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                    "action": .stringProperty("Action: start or stop"),
                    "path": .stringProperty("File path to save the recording (required for start)"),
                ],
                required: ["action"]
            )
        ),
        Tool(
            name: "sim_get_app_container",
            description: "Get the file path to an app's container directory on the simulator (for reading data, UserDefaults, databases)",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                    "bundle_id": .stringProperty("App bundle identifier"),
                    "container": .stringProperty("Container type: app, data, groups, or a specific app group ID (default: app)"),
                ],
                required: ["device", "bundle_id"]
            )
        ),
        Tool(
            name: "sim_add_media",
            description: "Add photos or videos to the simulator's photo library",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                    "path": .stringProperty("Path to the image or video file"),
                ],
                required: ["device", "path"]
            )
        ),
        Tool(
            name: "sim_biometric",
            description: "Simulate Face ID / Touch ID. Enroll biometrics, then trigger match or no-match.",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                    "action": .stringProperty("Action: enroll, match, or fail"),
                ],
                required: ["device", "action"]
            )
        ),
        Tool(
            name: "sim_privacy",
            description: "Grant, revoke, or reset privacy permissions for an app (e.g. camera, location, photos, notifications, contacts, microphone)",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                    "action": .stringProperty("Action: grant, revoke, or reset"),
                    "service": .stringProperty("Privacy service: all, calendar, contacts, location, microphone, motion, photos, camera, reminders, siri, speech-recognition, notifications"),
                    "bundle_id": .stringProperty("App bundle identifier"),
                ],
                required: ["device", "action", "service", "bundle_id"]
            )
        ),
        Tool(
            name: "sim_erase",
            description: "Erase all content and settings from a simulator (must be shut down first)",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                ],
                required: ["device"]
            )
        ),
        Tool(
            name: "sim_uninstall_app",
            description: "Uninstall an app from the simulator",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                    "bundle_id": .stringProperty("App bundle identifier to uninstall"),
                ],
                required: ["device", "bundle_id"]
            )
        ),
        Tool(
            name: "sim_screenshot",
            description: "Take a screenshot of the simulator and return it as an image",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                    "save_path": .stringProperty("File path to save the screenshot to"),
                ]
            )
        ),
        Tool(
            name: "sim_set_appearance",
            description: "Switch between light and dark mode",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                    "mode": .stringProperty("Appearance mode: light or dark"),
                ],
                required: ["device", "mode"]
            )
        ),
        Tool(
            name: "sim_set_locale",
            description: "Change simulator locale and language (requires reboot)",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                    "locale": .stringProperty("Locale identifier (e.g. en_US, ja_JP)"),
                    "language": .stringProperty("Language code (e.g. en, ja)"),
                ],
                required: ["device", "locale", "language"]
            )
        ),
        Tool(
            name: "sim_clear_status_bar",
            description: "Clear all status bar overrides and restore defaults",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                ],
                required: ["device"]
            )
        ),
        Tool(
            name: "sim_set_status_bar",
            description: "Override status bar display (time, battery, signal)",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                    "time": .stringProperty("Time string (e.g. 9:41)"),
                    "battery_level": .numberProperty("Battery level 0-100"),
                    "battery_state": .stringProperty("Battery state: charged, charging, or discharging (default: discharging)"),
                    "cellular_bars": .numberProperty("Cellular signal bars 0-4"),
                    "wifi_bars": .numberProperty("WiFi signal bars 0-3"),
                    "operator_name": .stringProperty("Carrier/operator name"),
                ],
                required: ["device"]
            )
        ),
        Tool(
            name: "sim_get_logs",
            description: "Get recent device logs, optionally filtered",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                    "filter": .stringProperty("Log predicate filter"),
                    "lines": .numberProperty("Number of recent log entries (default 50)"),
                ]
            )
        ),
        Tool(
            name: "sim_open_url",
            description: "Open a URL / deep link in the simulator",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                    "url": .stringProperty("URL or deep link to open"),
                ],
                required: ["device", "url"]
            )
        ),
        Tool(
            name: "sim_push_notification",
            description: "Send a push notification to the simulator",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                    "bundle_id": .stringProperty("Target app bundle identifier"),
                    "title": .stringProperty("Notification title"),
                    "body": .stringProperty("Notification body"),
                ],
                required: ["device", "bundle_id", "title", "body"]
            )
        ),
        Tool(
            name: "sim_set_location",
            description: "Set simulated GPS location",
            inputSchema: toolSchema(
                properties: [
                    "device": .stringProperty("Simulator name or UDID"),
                    "latitude": .numberProperty("Latitude"),
                    "longitude": .numberProperty("Longitude"),
                ],
                required: ["device", "latitude", "longitude"]
            )
        ),
    ]
}

func handleSimctlTool(
    name: String,
    args: [String: Value]?,
    simctl: SimctlService,
    screenshotService: ScreenshotService
) async throws -> CallTool.Result {
    switch name {
    case "sim_list_devices":
        let devices = try await simctl.listDevices()
        let json = devices.map { [
            "name": $0.name, "udid": $0.udid, "state": $0.state,
            "runtime": $0.runtime, "isAvailable": $0.isAvailable ? "true" : "false",
        ] }
        let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        return .init(content: [.text(String(data: data, encoding: .utf8) ?? "[]")])

    case "sim_boot":
        let device = try args?.require("device") ?? ""
        let udid = try await simctl.bootDevice(device)
        return try successResponse(["udid": udid])

    case "sim_shutdown":
        let device = try args?.require("device") ?? ""
        try await simctl.shutdownDevice(device)
        return try successResponse()

    case "sim_install_app":
        let device = try args?.require("device") ?? ""
        let appPath = try args?.require("app_path") ?? ""
        let udid = try await simctl.resolveDevice(device)
        try await simctl.installApp(deviceUdid: udid, appPath: appPath)
        return try successResponse()

    case "sim_launch_app":
        let device = try args?.require("device") ?? ""
        let bundleId = try args?.require("bundle_id") ?? ""
        let udid = try await simctl.resolveDevice(device)
        try await simctl.launchApp(deviceUdid: udid, bundleId: bundleId)
        return try successResponse()

    case "sim_keychain":
        let device = try args?.require("device") ?? ""
        let action = try args?.require("action") ?? ""
        let udid = try await simctl.resolveDevice(device)
        switch action {
        case "add-root-cert":
            let certPath = try args?.require("cert_path") ?? ""
            try await simctl.addRootCertificate(deviceUdid: udid, certPath: certPath)
        case "reset":
            try await simctl.resetKeychain(deviceUdid: udid)
        default:
            return .init(content: [.text("Invalid action: \(action). Use add-root-cert or reset")], isError: true)
        }
        return try successResponse()

    case "sim_record_video":
        let action = try args?.require("action") ?? ""
        if action == "start" {
            let device = try args?.require("device") ?? ""
            let udid = try await simctl.resolveDevice(device)
            let path = args?.string("path")
                ?? NSTemporaryDirectory() + "recording-\(UUID().uuidString).mp4"
            try await simctl.startRecording(deviceUdid: udid, path: path)
            return try successResponse(["recording": true, "path": path])
        } else if action == "stop" {
            await simctl.stopRecording()
            return try successResponse(["recording": false])
        } else {
            return .init(content: [.text("Invalid action: \(action). Use start or stop")], isError: true)
        }

    case "sim_get_app_container":
        let device = try args?.require("device") ?? ""
        let bundleId = try args?.require("bundle_id") ?? ""
        let container = args?.string("container") ?? "app"
        let udid = try await simctl.resolveDevice(device)
        let path = try await simctl.getAppContainer(deviceUdid: udid, bundleId: bundleId, container: container)
        return try successResponse(["path": path])

    case "sim_add_media":
        let device = try args?.require("device") ?? ""
        let path = try args?.require("path") ?? ""
        let udid = try await simctl.resolveDevice(device)
        try await simctl.addMedia(deviceUdid: udid, path: path)
        return try successResponse()

    case "sim_biometric":
        let device = try args?.require("device") ?? ""
        let action = try args?.require("action") ?? ""
        let udid = try await simctl.resolveDevice(device)
        switch action {
        case "enroll": try await simctl.enrollBiometric(deviceUdid: udid)
        case "match": try await simctl.matchBiometric(deviceUdid: udid)
        case "fail": try await simctl.failBiometric(deviceUdid: udid)
        default: return .init(content: [.text("Invalid action: \(action). Use enroll, match, or fail")], isError: true)
        }
        return try successResponse()

    case "sim_privacy":
        let device = try args?.require("device") ?? ""
        let action = try args?.require("action") ?? ""
        let service = try args?.require("service") ?? ""
        let bundleId = try args?.require("bundle_id") ?? ""
        let udid = try await simctl.resolveDevice(device)
        try await simctl.setPrivacy(deviceUdid: udid, action: action, service: service, bundleId: bundleId)
        return try successResponse()

    case "sim_erase":
        let device = try args?.require("device") ?? ""
        try await simctl.eraseDevice(device)
        return try successResponse()

    case "sim_uninstall_app":
        let device = try args?.require("device") ?? ""
        let bundleId = try args?.require("bundle_id") ?? ""
        let udid = try await simctl.resolveDevice(device)
        try await simctl.uninstallApp(deviceUdid: udid, bundleId: bundleId)
        return try successResponse()

    case "sim_screenshot":
        let device = args?.string("device")
        let savePath = args?.string("save_path")

        let udid: String
        if let device {
            udid = try await simctl.resolveDevice(device)
        } else {
            let devices = try await simctl.listDevices()
            guard let booted = devices.first(where: { $0.state == "Booted" }) else {
                return .init(content: [.text("No booted simulator found.")], isError: true)
            }
            udid = booted.udid
        }

        let effectivePath: String
        if let savePath {
            effectivePath = savePath
        } else {
            let screenshotsDir = NSTemporaryDirectory() + "ios-mcp-screenshots"
            try FileManager.default.createDirectory(atPath: screenshotsDir, withIntermediateDirectories: true)
            effectivePath = screenshotsDir + "/screenshot-\(UUID().uuidString).png"
        }

        let result = try await screenshotService.captureScreenshot(deviceUdid: udid, savePath: effectivePath)

        return .init(content: [
            .image(data: result.base64, mimeType: "image/png", metadata: nil),
            .text("Screenshot captured from \(result.deviceName) (\(result.width)x\(result.height)) — saved to \(result.filePath)"),
        ])

    case "sim_set_appearance":
        let device = try args?.require("device") ?? ""
        let mode = try args?.require("mode") ?? ""
        let udid = try await simctl.resolveDevice(device)
        try await simctl.setAppearance(deviceUdid: udid, mode: mode)
        return try successResponse()

    case "sim_set_locale":
        let device = try args?.require("device") ?? ""
        let locale = try args?.require("locale") ?? ""
        let language = try args?.require("language") ?? ""
        let udid = try await simctl.resolveDevice(device)
        try await simctl.setLocale(deviceUdid: udid, locale: locale, language: language)
        return try successResponse(["note": "Device rebooted with new locale"])

    case "sim_clear_status_bar":
        let device = try args?.require("device") ?? ""
        let udid = try await simctl.resolveDevice(device)
        try await simctl.clearStatusBar(deviceUdid: udid)
        return try successResponse()

    case "sim_set_status_bar":
        let device = try args?.require("device") ?? ""
        let udid = try await simctl.resolveDevice(device)
        let batteryLevel = args?.int("battery_level")
        let batteryState = args?.string("battery_state")
            ?? (batteryLevel != nil ? "discharging" : nil)
        let overrides = StatusBarOverrides(
            time: args?.string("time"),
            batteryLevel: batteryLevel,
            batteryState: batteryState,
            cellularBars: args?.int("cellular_bars"),
            wifiBars: args?.int("wifi_bars"),
            operatorName: args?.string("operator_name")
        )
        try await simctl.setStatusBar(deviceUdid: udid, overrides: overrides)
        return try successResponse()

    case "sim_get_logs":
        let device = args?.string("device")
        let udid: String
        if let device {
            udid = try await simctl.resolveDevice(device)
        } else {
            let devices = try await simctl.listDevices()
            guard let booted = devices.first(where: { $0.state == "Booted" }) else {
                return .init(content: [.text("No booted simulator found.")], isError: true)
            }
            udid = booted.udid
        }
        let logs = try await simctl.getLogs(
            deviceUdid: udid,
            filter: args?.string("filter"),
            lines: args?.int("lines") ?? 50
        )
        return .init(content: [.text(logs)])

    case "sim_open_url":
        let device = try args?.require("device") ?? ""
        let url = try args?.require("url") ?? ""
        let udid = try await simctl.resolveDevice(device)
        try await simctl.openURL(deviceUdid: udid, url: url)
        return try successResponse()

    case "sim_push_notification":
        let device = try args?.require("device") ?? ""
        let bundleId = try args?.require("bundle_id") ?? ""
        let title = try args?.require("title") ?? ""
        let body = try args?.require("body") ?? ""
        let udid = try await simctl.resolveDevice(device)
        try await simctl.sendPushNotification(
            deviceUdid: udid,
            bundleId: bundleId,
            payload: ["alert": ["title": title, "body": body]]
        )
        return try successResponse()

    case "sim_set_location":
        let device = try args?.require("device") ?? ""
        let lat = try args?.requireDouble("latitude")  ?? 0
        let lng = try args?.requireDouble("longitude") ?? 0
        let udid = try await simctl.resolveDevice(device)
        try await simctl.setLocation(deviceUdid: udid, lat: lat, lng: lng)
        return try successResponse()

    default:
        return .init(content: [.text("Unknown tool: \(name)")], isError: true)
    }
}
