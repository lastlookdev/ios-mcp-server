# ios-mcp-server

MCP server that gives Claude the ability to control iOS simulators and automate app UI through XCUITest. It handles everything — booting simulators, installing apps, taking screenshots, reading the screen, tapping buttons, typing text, and more — across 39 tools.

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
- Server runs at `http://localhost:9741/mcp`

**You may need to restart Claude Code for the new MCP server to be picked up.**

## Commands

```
ios-mcp-server              # Run in foreground (default port 9741)
ios-mcp-server start -p 8080  # Run on a custom port
ios-mcp-server install      # Install as background service + add to Claude Code
ios-mcp-server uninstall    # Remove service + Claude Code config
ios-mcp-server status       # Check if running
```

## Example Prompts

Once installed, you can ask Claude things like:

- "Boot the iPhone 17 Pro simulator and take a screenshot"
- "Read the screen and tap the Login button"
- "Set the simulator to dark mode and change the locale to Japanese"
- "Grant camera permissions to com.example.app"
- "Send a push notification with title 'Hello' to my app"
- "Start recording the simulator screen"

For UI automation (tapping, typing, reading the screen), Claude will use the XCUITest bridge. For simulator management (boot, install, screenshot, permissions), everything works directly.

## Setup

All tools work out of the box after running `ios-mcp-server install`. The UI automation tools (`ui_*`) use a built-in runner project that ships with the server — no configuration needed.

If you want to use a custom XCUITest runner instead of the built-in one, integrate the [XCUIBridge](https://github.com/lastlookdev/xcui-bridge) library into your own XCUITest target, then add the runner config to your project's `CLAUDE.md`:

```markdown
When using ui_start_bridge, use this runner configuration:
- project_path: /path/to/MyRunner.xcodeproj
- scheme: MyUITests
- test_identifier: MyUITests/MyUITests/testBridge
```

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
