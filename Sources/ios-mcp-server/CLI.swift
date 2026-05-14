import ArgumentParser
import Foundation
import IOSMCPServer

private let defaultPort = 9741
private let serverName = "ios-mcp-server"
private let plistLabel = "dev.lastlook.iosmcpserver"
private let plistPath = NSHomeDirectory() + "/Library/LaunchAgents/\(plistLabel).plist"
private let logPath = "/tmp/ios-mcp-server.log"

enum ClientSelection: String, ExpressibleByArgument {
    case all
    case claude
    case codex

    var includesClaude: Bool { self == .all || self == .claude }
    var includesCodex: Bool { self == .all || self == .codex }

    var displayName: String {
        switch self {
        case .all: "Claude Code and Codex"
        case .claude: "Claude Code"
        case .codex: "Codex"
        }
    }
}

@main
struct IOSMCPServerCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ios-mcp-server",
        abstract: "iOS MCP server for controlling simulators and apps via XCUITest",
        subcommands: [Start.self, Install.self, Uninstall.self, Status.self, App.self],
        defaultSubcommand: Start.self
    )
}

// MARK: - Start

struct Start: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Start the server in foreground")

    @Option(name: .shortAndLong, help: "Port to listen on")
    var port: Int = defaultPort

    func run() async throws {
        let httpServer = MCPHTTPServer(port: port) {
            await createIOSMCPServer()
        }
        try await httpServer.start()
    }
}

// MARK: - Install

struct Install: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Install as background service and add to MCP client config")

    @Option(name: .shortAndLong, help: "Port to listen on")
    var port: Int = defaultPort

    @Option(help: "Client config to update: all, claude, or codex")
    var client: ClientSelection = .all

    func run() throws {
        let binaryPath = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0]).standardized.path

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(plistLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binaryPath)</string>
                <string>start</string>
                <string>--port</string>
                <string>\(port)</string>
            </array>
            <key>EnvironmentVariables</key>
            <dict>
                <key>PATH</key>
                <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
                <key>HOME</key>
                <string>\(NSHomeDirectory())</string>
                <key>GIT_SSH_COMMAND</key>
                <string>/usr/bin/ssh</string>
            </dict>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(logPath)</string>
            <key>StandardErrorPath</key>
            <string>\(logPath)</string>
        </dict>
        </plist>
        """

        try plist.write(toFile: plistPath, atomically: true, encoding: .utf8)

        _ = try runProcess("/bin/launchctl", arguments: ["unload", plistPath], allowFailure: true)
        try runProcess("/bin/launchctl", arguments: ["load", plistPath])

        let mcpURL = "http://localhost:\(port)/mcp"
        var updatedConfigs: [String] = []
        if client.includesClaude {
            try addToClaudeConfig(url: mcpURL)
            updatedConfigs.append("~/.claude.json")
        }
        if client.includesCodex {
            try addToCodexConfig(url: mcpURL)
            updatedConfigs.append("~/.codex/config.toml")
        }

        print("Installed and started.")
        print("  Server: \(mcpURL)")
        print("  Logs:   \(logPath)")
        print("  Added to \(updatedConfigs.joined(separator: ", "))")
    }
}

// MARK: - Uninstall

struct Uninstall: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Remove background service and MCP client config")

    @Option(help: "Client config to update: all, claude, or codex")
    var client: ClientSelection = .all

    @Flag(help: "Also remove the background service when uninstalling a single client config")
    var removeService = false

    func run() throws {
        let shouldRemoveService = client == .all || removeService
        if shouldRemoveService, FileManager.default.fileExists(atPath: plistPath) {
            _ = try runProcess("/bin/launchctl", arguments: ["unload", plistPath], allowFailure: true)
            try FileManager.default.removeItem(atPath: plistPath)
        }

        if client.includesClaude {
            try removeFromClaudeConfig()
        }
        if client.includesCodex {
            try removeFromCodexConfig()
        }

        if shouldRemoveService {
            print("Uninstalled. Removed service and \(client.displayName) config.")
        } else {
            print("Removed \(client.displayName) config. Service left installed.")
        }
    }
}

// MARK: - Status

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Check if the service is running")

    func run() {
        guard FileManager.default.fileExists(atPath: plistPath) else {
            print("Installed: no")
            print("Running:   no")
            print("Claude:    \(claudeConfigHasServer() ? "configured" : "not configured")")
            print("Codex:     \(codexConfigHasServer() ? "configured" : "not configured")")
            print("Apps:      \(savedAppCountDescription())")
            return
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["list", plistLabel]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()

        let running = task.terminationStatus == 0
        let port = installedServicePort() ?? defaultPort
        print("Installed: yes")
        print("Running:   \(running ? "yes" : "no")")
        print("Plist:     \(plistPath)")
        print("URL:       http://localhost:\(port)/mcp")
        print("Claude:    \(claudeConfigHasServer() ? "configured" : "not configured")")
        print("Codex:     \(codexConfigHasServer() ? "configured" : "not configured")")
        print("Apps:      \(savedAppCountDescription())")
    }
}

// MARK: - Saved App Config

struct App: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app",
        abstract: "Manage saved app build and runner configs",
        subcommands: [AppAdd.self, AppList.self, AppRemove.self]
    )
}

struct AppAdd: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Save app build settings and optional custom runner settings"
    )

    @Option(help: "Bundle ID of the app")
    var bundleId: String

    @Option(help: "Path to the app .xcodeproj or .xcworkspace")
    var project: String

    @Option(help: "App scheme to build and install before starting the bridge")
    var scheme: String

    @Flag(help: "Treat --project as a .xcworkspace")
    var workspace = false

    @Option(help: "Optional custom runner .xcodeproj or .xcworkspace. Defaults to --project when runner options are provided.")
    var runnerProject: String?

    @Option(help: "Optional custom runner scheme whose Test action includes the bridge UI test target")
    var runnerScheme: String?

    @Option(help: "Optional custom runner only-testing identifier, e.g. MyUITests/MyBridgeTests/testBridge")
    var runnerTestIdentifier: String?

    @Flag(help: "Treat --runner-project as a .xcworkspace")
    var runnerWorkspace = false

    func run() throws {
        let appProjectPath = try validatedPath(expandedPath(project), label: "App project")
        let runner = try resolvedRunner(appProjectPath: appProjectPath)

        let config = SavedAppConfiguration(
            app: SavedAppBuild(
                projectPath: appProjectPath,
                scheme: scheme,
                isWorkspace: workspace || isWorkspacePath(appProjectPath)
            ),
            runner: runner
        )

        try AppRegistry().set(config, for: bundleId)

        print("Saved app profile for \(bundleId).")
        print("  App:    \(appProjectPath)")
        print("  Scheme: \(scheme)")
        if let runner {
            print("  Runner: \(runner.projectPath)")
            print("  Runner scheme: \(runner.scheme)")
            print("  Runner test:   \(runner.testIdentifier)")
        } else {
            print("  Runner: built-in")
        }
    }

    private func resolvedRunner(appProjectPath: String) throws -> SavedCustomRunner? {
        let hasRunnerProject = runnerProject?.isEmpty == false
        let hasRunnerScheme = runnerScheme?.isEmpty == false
        let hasRunnerTest = runnerTestIdentifier?.isEmpty == false

        guard hasRunnerProject || hasRunnerScheme || hasRunnerTest else { return nil }
        guard let runnerScheme, !runnerScheme.isEmpty,
              let runnerTestIdentifier, !runnerTestIdentifier.isEmpty else {
            throw ValidationError("--runner-scheme and --runner-test-identifier must be provided together.")
        }

        let projectPath = try validatedPath(
            expandedPath(runnerProject ?? appProjectPath),
            label: "Runner project"
        )
        return SavedCustomRunner(
            projectPath: projectPath,
            scheme: runnerScheme,
            testIdentifier: runnerTestIdentifier,
            isWorkspace: runnerWorkspace || isWorkspacePath(projectPath)
        )
    }
}

struct AppList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List saved app profiles"
    )

    func run() throws {
        let configs = try AppRegistry().list()
        guard !configs.isEmpty else {
            print("No app profiles configured.")
            return
        }

        for item in configs {
            let config = item.configuration
            print(item.bundleId)
            if let app = config.app {
                print("  App:    \(app.projectPath)")
                print("  App scheme: \(app.scheme)")
            }
            if let runner = config.runner {
                print("  Runner: \(runner.projectPath)")
                print("  Runner scheme: \(runner.scheme)")
                print("  Runner test:   \(runner.testIdentifier)")
            } else {
                print("  Runner: built-in")
            }
        }
    }
}

struct AppRemove: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove a saved app profile"
    )

    @Option(help: "Bundle ID whose saved app profile should be removed")
    var bundleId: String

    func run() throws {
        if try AppRegistry().remove(bundleId: bundleId) {
            print("Removed app profile for \(bundleId).")
        } else {
            print("No app profile was configured for \(bundleId).")
        }
    }
}

// MARK: - Client Config

private func homeDirectory() -> String {
    if let pw = getpwuid(getuid()) {
        return String(cString: pw.pointee.pw_dir)
    }
    return NSHomeDirectory()
}

private func claudeConfigPath() -> String {
    homeDirectory() + "/.claude.json"
}

private func codexConfigPath() -> String {
    homeDirectory() + "/.codex/config.toml"
}

private func savedAppCountDescription() -> String {
    do {
        return "\(try AppRegistry().list().count)"
    } catch {
        return "unavailable"
    }
}

private func installedServicePort() -> Int? {
    guard let data = FileManager.default.contents(atPath: plistPath),
          let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
          let arguments = plist["ProgramArguments"] as? [String] else {
        return nil
    }

    for option in ["--port", "-p"] {
        if let index = arguments.firstIndex(of: option),
           arguments.indices.contains(index + 1) {
            return Int(arguments[index + 1])
        }
    }
    return nil
}

private func addToClaudeConfig(url: String) throws {
    let path = claudeConfigPath()
    var config: [String: Any] = [:]
    if let data = FileManager.default.contents(atPath: path),
       let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        config = existing
    }

    var servers = config["mcpServers"] as? [String: Any] ?? [:]
    servers[serverName] = ["type": "http", "url": url]
    config["mcpServers"] = servers

    let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: URL(fileURLWithPath: path))
}

private func removeFromClaudeConfig() throws {
    let path = claudeConfigPath()
    guard let data = FileManager.default.contents(atPath: path),
          var config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          var servers = config["mcpServers"] as? [String: Any] else { return }

    servers.removeValue(forKey: serverName)
    config["mcpServers"] = servers

    let newData = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
    try newData.write(to: URL(fileURLWithPath: path))
}

private func claudeConfigHasServer() -> Bool {
    let path = claudeConfigPath()
    guard let data = FileManager.default.contents(atPath: path),
          let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let servers = config["mcpServers"] as? [String: Any] else { return false }
    return servers[serverName] != nil
}

private func addToCodexConfig(url: String) throws {
    let path = codexConfigPath()
    let fileURL = URL(fileURLWithPath: path)
    let directoryURL = fileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true
    )

    let existing = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    var config = removeCodexServerBlock(from: existing)
        .trimmingCharacters(in: .newlines)

    if !config.isEmpty {
        config += "\n\n"
    }
    config += """
    [mcp_servers.\(serverName)]
    url = "\(tomlEscaped(url))"
    """
    config += "\n"

    try config.write(to: fileURL, atomically: true, encoding: .utf8)
}

private func removeFromCodexConfig() throws {
    let path = codexConfigPath()
    let fileURL = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else { return }

    let existing = try String(contentsOf: fileURL, encoding: .utf8)
    let config = removeCodexServerBlock(from: existing)
        .trimmingCharacters(in: .newlines) + "\n"
    try config.write(to: fileURL, atomically: true, encoding: .utf8)
}

private func codexConfigHasServer() -> Bool {
    guard let config = try? String(contentsOfFile: codexConfigPath(), encoding: .utf8) else {
        return false
    }
    return config.components(separatedBy: .newlines).contains { isCodexServerHeader($0) }
}

private func removeCodexServerBlock(from config: String) -> String {
    var result: [String] = []
    var skippingServerBlock = false

    for line in config.components(separatedBy: .newlines) {
        if isTomlTableHeader(line) {
            skippingServerBlock = isCodexServerHeader(line)
            if skippingServerBlock {
                continue
            }
        }

        if !skippingServerBlock {
            result.append(line)
        }
    }

    return result.joined(separator: "\n")
}

private func isTomlTableHeader(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    return trimmed.hasPrefix("[") && trimmed.hasSuffix("]")
}

private func isCodexServerHeader(_ line: String) -> Bool {
    let normalized = line
        .trimmingCharacters(in: .whitespaces)
        .replacingOccurrences(of: "\"", with: "")
        .replacingOccurrences(of: " ", with: "")
    return normalized == "[mcp_servers.\(serverName)]"
}

private func tomlEscaped(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
}

private func expandedPath(_ path: String) -> String {
    if path == "~" {
        return homeDirectory()
    }
    if path.hasPrefix("~/") {
        return homeDirectory() + String(path.dropFirst())
    }
    return URL(fileURLWithPath: path).standardized.path
}

private func validatedPath(_ path: String, label: String) throws -> String {
    guard FileManager.default.fileExists(atPath: path) else {
        throw ValidationError("\(label) does not exist: \(path)")
    }
    return path
}

private func isWorkspacePath(_ path: String) -> Bool {
    path.hasSuffix(".xcworkspace")
}

@discardableResult
private func runProcess(
    _ executable: String,
    arguments: [String],
    allowFailure: Bool = false
) throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let stderrPipe = Pipe()
    process.standardError = stderrPipe
    process.standardOutput = FileHandle.nullDevice

    try process.run()
    process.waitUntilExit()

    guard allowFailure || process.terminationStatus == 0 else {
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        throw ValidationError(
            "\(URL(fileURLWithPath: executable).lastPathComponent) \(arguments.joined(separator: " ")) failed with exit \(process.terminationStatus): \(stderr)"
        )
    }

    return process.terminationStatus
}
