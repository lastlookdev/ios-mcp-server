# Runner

Built-in XCUITest runner project used by the iOS MCP server.

## What This Is

A minimal Xcode project with two targets:

- **Runner** — empty iOS app (required by Xcode as a host for UI tests)
- **RunnerUITests** — UI test bundle with a `BridgeTestCase` subclass that controls any app by bundle ID

The MCP server runs `xcodebuild test` against this project to establish a bridge for UI automation.

## Usage

Register this project as a custom runner on an app profile:

```sh
ios-mcp-server app add \
  --bundle-id com.example.App \
  --project /path/to/App/App.xcodeproj \
  --scheme App \
  --runner-project /path/to/Runner/Runner.xcodeproj \
  --runner-scheme RunnerUITests \
  --runner-test-identifier RunnerUITests/RunnerUITests/testBridge
```

Or pass this project's path directly to `ui_start_bridge`:

```
ui_start_bridge(
  device: "iPhone 17 Pro",
  bundle_id: "com.example.App",
  custom_runner_project_path: "/path/to/Runner/Runner.xcodeproj",
  custom_runner_scheme: "RunnerUITests",
  custom_runner_test_identifier: "RunnerUITests/RunnerUITests/testBridge"
)
```

## Build Settings

- `CODE_SIGNING_ALLOWED = NO` — no Apple Developer account needed
- No `DEVELOPMENT_TEAM` — works on any machine
- XCUIBridge is a remote SPM dependency from GitHub
- Only the `RunnerUITests` scheme exists (shared)
