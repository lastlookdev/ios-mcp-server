import Foundation
import Testing
@testable import IOSMCPServer

@Suite("Tool Helpers")
struct ToolHelpersTests {

    @Test("Process environment includes standard tool paths")
    func processEnvironmentIncludesToolPaths() {
        let environment = processEnvironment(overrides: ["PATH": ""])
        let path = environment["PATH"] ?? ""

        #expect(path.split(separator: ":").contains("/usr/bin"))
        #expect(path.split(separator: ":").contains("/bin"))
        #expect(path.split(separator: ":").contains("/usr/sbin"))
        #expect(path.split(separator: ":").contains("/sbin"))
    }

    @Test("Process environment pins ssh when no Git SSH override exists")
    func processEnvironmentPinsSSH() {
        let environment = processEnvironment(overrides: [
            "GIT_SSH": "",
            "GIT_SSH_COMMAND": "",
        ])

        if FileManager.default.isExecutableFile(atPath: "/usr/bin/ssh") {
            #expect(environment["GIT_SSH_COMMAND"] == "/usr/bin/ssh")
        }
    }
}
