# Runner

Built-in XCUITest runner project used by the iOS MCP server.

## What This Is

A minimal Xcode project with two targets:

- **Runner** — empty iOS app (required by Xcode as a host for UI tests)
- **RunnerUITests** — UI test bundle with a `BridgeTestCase` subclass that controls any app by bundle ID

The MCP server runs `xcodebuild test` against this project to establish a bridge for UI automation.

## Usage

Pass this project's path to `ui_start_bridge`:

```
ui_start_bridge(
  device: "iPhone 17 Pro",
  bundle_id: "com.example.App",
  project_path: "/path/to/Runner/Runner.xcodeproj",
  scheme: "RunnerUITests",
  test_identifier: "RunnerUITests/RunnerUITests/testBridge"
)
```

## Build Settings

- `CODE_SIGNING_ALLOWED = NO` — no Apple Developer account needed
- No `DEVELOPMENT_TEAM` — works on any machine
- XCUIBridge is a remote SPM dependency from GitHub
- Only the `RunnerUITests` scheme exists (shared)
