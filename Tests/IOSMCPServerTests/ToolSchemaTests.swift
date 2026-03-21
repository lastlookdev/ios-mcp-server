import Testing
import Foundation
@testable import IOSMCPServer

@Suite("Tool Schema Validation")
struct ToolSchemaTests {

    @Test("All simctl tools have valid inputSchema with type object")
    func simctlToolSchemas() throws {
        for tool in simctlTools() {
            let schema = tool.inputSchema
            guard case .object(let dict) = schema else {
                Issue.record("Tool \(tool.name) has non-object inputSchema")
                continue
            }
            guard case .string(let typeVal) = dict["type"] else {
                Issue.record("Tool \(tool.name) is missing 'type' in inputSchema")
                continue
            }
            #expect(typeVal == "object", "Tool \(tool.name) has type '\(typeVal)' instead of 'object'")
        }
    }

    @Test("All xcuitest tools have valid inputSchema with type object")
    func xcuitestToolSchemas() throws {
        for tool in xcuitestTools() {
            let schema = tool.inputSchema
            guard case .object(let dict) = schema else {
                Issue.record("Tool \(tool.name) has non-object inputSchema")
                continue
            }
            guard case .string(let typeVal) = dict["type"] else {
                Issue.record("Tool \(tool.name) is missing 'type' in inputSchema")
                continue
            }
            #expect(typeVal == "object", "Tool \(tool.name) has type '\(typeVal)' instead of 'object'")
        }
    }

    @Test("All tools have unique names")
    func uniqueToolNames() {
        let allTools = simctlTools() + xcuitestTools()
        let names = allTools.map(\.name)
        let uniqueNames = Set(names)
        #expect(names.count == uniqueNames.count, "Duplicate tool names found")
    }

    @Test("All tools have non-empty descriptions")
    func toolDescriptions() {
        let allTools = simctlTools() + xcuitestTools()
        for tool in allTools {
            #expect(!(tool.description ?? "").isEmpty, "Tool \(tool.name) has empty description")
        }
    }

    @Test("Tool count matches simctl + xcuitest")
    func toolCount() {
        let allTools = simctlTools() + xcuitestTools()
        #expect(allTools.count == simctlTools().count + xcuitestTools().count)
        #expect(allTools.count >= 22, "Should have at least 22 tools")
    }

    @Test("Simctl tools have expected names")
    func simctlToolNames() {
        let names = Set(simctlTools().map(\.name))
        let expected: Set<String> = [
            "sim_list_devices", "sim_boot", "sim_shutdown", "sim_erase",
            "sim_keychain", "sim_record_video", "sim_get_app_container",
            "sim_add_media", "sim_biometric", "sim_privacy",
            "sim_install_app", "sim_launch_app", "sim_uninstall_app",
            "sim_screenshot",
            "sim_set_appearance", "sim_set_locale",
            "sim_clear_status_bar", "sim_set_status_bar",
            "sim_get_logs", "sim_open_url", "sim_push_notification",
            "sim_set_location",
        ]
        #expect(names == expected)
    }

    @Test("XCUITest tools have expected names")
    func xcuitestToolNames() {
        let names = Set(xcuitestTools().map(\.name))
        let expected: Set<String> = [
            "ui_start_bridge", "ui_tap", "ui_type",
            "ui_swipe", "ui_scroll", "ui_read_screen",
            "ui_wait_for", "ui_stop_bridge",
            "ui_long_press", "ui_double_tap",
            "ui_adjust_slider", "ui_adjust_picker",
            "ui_pinch", "ui_drag",
            "ui_element_info", "ui_element_count",
            "ui_dismiss_keyboard", "ui_dismiss_modal",
        ]
        #expect(names == expected)
    }

    @Test("Required fields are present in tool schemas")
    func requiredFieldsPresent() {
        let bootTool = simctlTools().first(where: { $0.name == "sim_boot" })!
        guard case .object(let schema) = bootTool.inputSchema,
              case .array(let required) = schema["required"] else {
            Issue.record("sim_boot missing required array")
            return
        }
        let requiredNames = required.compactMap { value -> String? in
            guard case .string(let s) = value else { return nil }
            return s
        }
        #expect(requiredNames.contains("device"))
    }

    @Test("ui_start_bridge requires device, bundle_id, and runner config")
    func bridgeRequiredFields() {
        let tool = xcuitestTools().first(where: { $0.name == "ui_start_bridge" })!
        guard case .object(let schema) = tool.inputSchema,
              case .array(let required) = schema["required"] else {
            Issue.record("ui_start_bridge missing required array")
            return
        }
        let requiredNames = required.compactMap { value -> String? in
            guard case .string(let s) = value else { return nil }
            return s
        }
        #expect(requiredNames.contains("device"))
        #expect(requiredNames.contains("bundle_id"))
        #expect(requiredNames.contains("project_path"))
        #expect(requiredNames.contains("scheme"))
        #expect(requiredNames.contains("test_identifier"))
    }
}
