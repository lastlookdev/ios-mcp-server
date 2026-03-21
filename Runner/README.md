# Runner

Built-in XCUITest runner project used by the iOS MCP server. Users do not interact with this directly.

## What This Is

A minimal Xcode project with two targets:

- **Runner** — empty iOS app (required by Xcode as a host for UI tests)
- **RunnerUITests** — UI test bundle with a `BridgeTestCase` subclass that controls any app by bundle ID

The MCP server copies this project to `~/Library/Application Support/LastLook/Runner/` at runtime and runs `xcodebuild test` against it.

## Build Settings

- `CODE_SIGNING_ALLOWED = NO` — no Apple Developer account needed
- No `DEVELOPMENT_TEAM` — works on any machine
- XCUIBridge is a remote SPM dependency from GitHub
- Only the `RunnerUITests` scheme exists (shared)

## Updating

If XCUIBridge changes, bump the version tag in the `XCRemoteSwiftPackageReference` in `project.pbxproj`, and increment `RunnerProject.runnerVersion` in the MCP server to trigger re-setup on next use.
