# ios-mcp-server

MCP server for controlling iOS simulators and apps via XCUITest.

## Install

**Homebrew:**

```sh
brew install lastlookdev/tap/ios-mcp-server
ios-mcp-server install
```

**From source:**

```sh
git clone https://github.com/lastlookdev/ios-mcp-server.git
cd ios-mcp-server
swift build -c release
.build/release/ios-mcp-server install
```

`install` starts a background service (via launchd) and adds the server to Claude Code's `~/.claude.json` automatically. The server runs at `http://localhost:9741/mcp`.

## Commands

```
ios-mcp-server              # Run in foreground
ios-mcp-server install      # Install as background service + add to Claude Code
ios-mcp-server uninstall    # Remove service + Claude Code config
ios-mcp-server status       # Check if running
```

## MCP Tools

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
| `sim_keychain` | Reset keychain |
| `sim_add_media` | Add photos/videos |
| `sim_get_app_container` | Get app container path |

## ui_start_bridge Options

**Minimal** — just device and bundle ID (app must already be installed):
```
ui_start_bridge(device: "iPhone 17 Pro", bundle_id: "com.example.App")
```

**Build and install** — builds the user's app before starting:
```
ui_start_bridge(
  device: "iPhone 17 Pro",
  bundle_id: "com.example.App",
  app_project_path: "/path/to/App.xcodeproj",
  app_scheme: "App"
)
```

## Requirements

- macOS 14+
- Xcode with iOS Simulator support
