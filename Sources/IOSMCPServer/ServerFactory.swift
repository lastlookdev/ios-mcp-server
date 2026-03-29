import MCP

package func createIOSMCPServer() async -> Server {
    let simctl = SimctlService()
    let screenshotService = ScreenshotService(simctl: simctl)
    let bridge = XCUITestBridge()

    let server = Server(
        name: "ios-mcp-server",
        version: "0.0.1",
        capabilities: .init(tools: .init(listChanged: false))
    )

    let simTools = simctlTools()
    let uiTools = xcuitestTools()
    let allTools = simTools + uiTools
    let simctlNames = Set(simTools.map(\.name))
    let xcuitestNames = Set(uiTools.map(\.name))

    await server.withMethodHandler(ListTools.self) { _ in
        ListTools.Result(tools: allTools)
    }

    await server.withMethodHandler(CallTool.self) { params in
        do {
            if simctlNames.contains(params.name) {
                return try await handleSimctlTool(
                    name: params.name,
                    args: params.arguments,
                    simctl: simctl,
                    screenshotService: screenshotService
                )
            } else if xcuitestNames.contains(params.name) {
                return try await handleXCUITestTool(
                    name: params.name,
                    args: params.arguments,
                    bridge: bridge,
                    simctl: simctl
                )
            } else {
                return CallTool.Result(content: [.text("Unknown tool: \(params.name)")], isError: true)
            }
        } catch {
            return CallTool.Result(content: [.text("Error: \(error.localizedDescription)")], isError: true)
        }
    }

    return server
}
