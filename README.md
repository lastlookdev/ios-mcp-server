# ios-mcp-server

MCP server that gives Claude Code and Codex the ability to control iOS simulators and automate app UI through XCUITest. It handles everything — booting simulators, building and installing apps, taking screenshots, reading the screen, tapping buttons, typing text, and more — across 40 tools.

## Requirements

- macOS 14+
- Xcode with iOS Simulator support

## Install

```sh
brew install lastlookdev/tap/ios-mcp-server
ios-mcp-server install
```

That's it. The `install` command handles everything:
- Starts a background service via launchd
- Registers the server in Claude Code's `~/.claude.json`
- Registers the server in Codex's `~/.codex/config.toml`
- Server runs at `http://localhost:9741/mcp`

**You may need to restart Claude Code or Codex for the new MCP server to be picked up.**

## Commands

```
ios-mcp-server              # Run in foreground (default port 9741)
ios-mcp-server start -p 8080  # Run on a custom port
ios-mcp-server install      # Install service + add to Claude Code and Codex
ios-mcp-server install --client codex   # Install service + add only to Codex
ios-mcp-server install --client claude  # Install service + add only to Claude Code
ios-mcp-server uninstall    # Remove service + Claude Code and Codex config
ios-mcp-server uninstall --client codex # Remove only Codex config, leave service installed
ios-mcp-server status       # Check if running
ios-mcp-server app add --bundle-id com.example.App --project /path/to/MyApp.xcodeproj --scheme MyApp # Optional manual profile
ios-mcp-server app list
```

## Example Prompts

Once installed, you can ask Claude Code or Codex things like:

- "Boot the iPhone 17 Pro simulator and take a screenshot"
- "Start my app on the iPhone 17 Pro simulator and tap through the login flow"
- "Read the screen and tap the Login button"
- "Set the simulator to dark mode and change the locale to Japanese"
- "Grant camera permissions to com.example.app"
- "Send a push notification with title 'Hello' to my app"
- "Start recording the simulator screen"

For UI automation (tapping, typing, reading the screen), your MCP client will use the XCUITest bridge. For simulator management (boot, install, screenshot, permissions), everything works directly.

## Setup

All tools work out of the box after running `ios-mcp-server install`. For normal app flows, agents should start the XCUITest bridge instead of running `xcodebuild` manually:

```json
{
  "device": "iPhone 17 Pro",
  "bundle_id": "com.example.App"
}
```

The agent can pass project and scheme details directly to `ui_start_bridge` when it already knows them. If those details are missing, the server asks the MCP client for workspace roots and discovers the matching Xcode project and scheme from the bundle ID. The bridge start flow boots the simulator, builds and installs the app from the background service when needed, launches the app, and starts the built-in XCUITest runner.

Manual app profiles are optional. Use `app add` only when your client does not provide workspace roots, auto-discovery cannot identify the right scheme, or you want to pin a specific project/scheme:

```sh
ios-mcp-server app add \
  --bundle-id com.example.App \
  --project /path/to/MyApp.xcodeproj \
  --scheme MyApp
```

After that, agents still use the same minimal tool arguments:

```json
{
  "device": "iPhone 17 Pro",
  "bundle_id": "com.example.App"
}
```

Custom runners are optional. Use one only when you need app-specific UI test setup before the bridge starts. First add [XCUIBridge](https://github.com/lastlookdev/xcui-bridge) to an iOS UI test target, then save the runner details on the app profile:

```sh
ios-mcp-server app add \
  --bundle-id com.example.App \
  --project /path/to/MyApp.xcodeproj \
  --scheme MyApp \
  --runner-scheme MyAppUITests \
  --runner-test-identifier MyAppUITests/MyBridgeTests/testBridge
```

A custom runner needs:

- An iOS UI test target that depends on `XCUIBridge`
- A `BridgeTestCase` subclass, for example `final class MyBridgeTests: BridgeTestCase {}`
- A shared Xcode scheme whose Test action includes that UI test target
- The Xcode `-only-testing` identifier for the bridge test, usually `UITestTarget/ClassName/testBridge`

If the app project is a workspace, add `--workspace`. If the runner lives in a different project or workspace, also pass `--runner-project /path/to/Runner.xcodeproj` and `--runner-workspace` when needed. One-off overrides are still supported with `custom_runner_project_path`, `custom_runner_scheme`, `custom_runner_test_identifier`, and optionally `custom_runner_is_workspace` on `ui_start_bridge`, but saved app profiles are the recommended path.

## MCP Tools

### Simulator

| Tool | Description |
|---|---|
| `sim_list_devices` | List all simulators and their state |
| `sim_boot` / `sim_shutdown` | Boot or shut down a simulator |
| `sim_screenshot` | Capture simulator screenshot |
| `sim_install_app` / `sim_uninstall_app` | Install or remove an app |
| `sim_launch_app` | Launch an app |
| `sim_erase` | Erase simulator content |
| `sim_privacy` | Set privacy permissions |
| `sim_push_notification` | Send a push notification |
| `sim_set_location` | Set simulated GPS location |
| `sim_open_url` | Open a URL |
| `sim_set_appearance` | Set light/dark mode |
| `sim_set_locale` | Set language and locale |
| `sim_set_status_bar` / `sim_clear_status_bar` | Override or reset status bar |
| `sim_record_video` | Start/stop screen recording |
| `sim_get_logs` | Fetch simulator logs |
| `sim_biometric` | Enroll/match/fail biometrics |
| `sim_keychain` | Manage keychain |
| `sim_add_media` | Add photos/videos |
| `sim_get_app_container` | Get app container path |

### UI Control (requires bridge)

| Tool | Description |
|---|---|
| `ui_start_bridge` | Start the XCUITest bridge |
| `ui_stop_bridge` | Stop the bridge |
| `ui_read_screen` | Read the accessibility tree |
| `ui_tap` | Tap an element |
| `ui_type` | Type text |
| `ui_swipe` | Swipe in a direction |
| `ui_scroll` | Scroll a container |
| `ui_long_press` | Long press an element |
| `ui_double_tap` | Double tap an element |
| `ui_pinch` | Pinch to zoom |
| `ui_drag` | Drag between elements |
| `ui_adjust_slider` | Set slider value |
| `ui_adjust_picker` | Select picker value |
| `ui_element_info` | Get element properties |
| `ui_element_count` | Count elements by type |
| `ui_wait_for` | Wait for element to appear |
| `ui_dismiss_keyboard` | Dismiss keyboard |
| `ui_dismiss_modal` | Dismiss alert/sheet/popover/menu |
