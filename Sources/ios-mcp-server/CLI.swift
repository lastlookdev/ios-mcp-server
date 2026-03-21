import ArgumentParser
import Foundation
import IOSMCPServer

private let defaultPort = 9741
private let plistLabel = "dev.lastlook.iosmcpserver"
private let plistPath = NSHomeDirectory() + "/Library/LaunchAgents/\(plistLabel).plist"

@main
struct IOSMCPServerCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ios-mcp-server",
        abstract: "iOS MCP server for controlling simulators and apps via XCUITest",
        subcommands: [Start.self, Install.self, Uninstall.self, Status.self],
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
    static let configuration = CommandConfiguration(abstract: "Install as background service and add to Claude Code")

    @Option(name: .shortAndLong, help: "Port to listen on")
    var port: Int = defaultPort

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
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>/tmp/ios-mcp-server.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/ios-mcp-server.log</string>
        </dict>
        </plist>
        """

        try plist.write(toFile: plistPath, atomically: true, encoding: .utf8)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["load", plistPath]
        try task.run()
        task.waitUntilExit()

        let mcpURL = "http://localhost:\(port)/mcp"
        try addToClaudeConfig(url: mcpURL)

        print("Installed and started.")
        print("  Server: \(mcpURL)")
        print("  Logs:   /tmp/ios-mcp-server.log")
        print("  Added to ~/.claude.json")
    }
}

// MARK: - Uninstall

struct Uninstall: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Remove background service and Claude Code config")

    func run() throws {
        if FileManager.default.fileExists(atPath: plistPath) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = ["unload", plistPath]
            try task.run()
            task.waitUntilExit()
            try FileManager.default.removeItem(atPath: plistPath)
        }

        try removeFromClaudeConfig()
        print("Uninstalled. Removed service and Claude Code config.")
    }
}

// MARK: - Status

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Check if the service is running")

    func run() {
        guard FileManager.default.fileExists(atPath: plistPath) else {
            print("Not installed.")
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
        print("Installed: yes")
        print("Running:   \(running ? "yes" : "no")")
        print("Plist:     \(plistPath)")
        print("URL:       http://localhost:\(defaultPort)/mcp")
    }
}

// MARK: - Claude Code Config

private func claudeConfigPath() -> String {
    if let pw = getpwuid(getuid()) {
        return String(cString: pw.pointee.pw_dir) + "/.claude.json"
    }
    return NSHomeDirectory() + "/.claude.json"
}

private func addToClaudeConfig(url: String) throws {
    let path = claudeConfigPath()
    var config: [String: Any] = [:]
    if let data = FileManager.default.contents(atPath: path),
       let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        config = existing
    }

    var servers = config["mcpServers"] as? [String: Any] ?? [:]
    servers["ios-mcp-server"] = ["type": "http", "url": url]
    config["mcpServers"] = servers

    let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: URL(fileURLWithPath: path))
}

private func removeFromClaudeConfig() throws {
    let path = claudeConfigPath()
    guard let data = FileManager.default.contents(atPath: path),
          var config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          var servers = config["mcpServers"] as? [String: Any] else { return }

    servers.removeValue(forKey: "ios-mcp-server")
    config["mcpServers"] = servers

    let newData = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
    try newData.write(to: URL(fileURLWithPath: path))
}
