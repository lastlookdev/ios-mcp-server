import Foundation
import Testing
@testable import IOSMCPServer

@Suite("HTTP Server")
struct HTTPServerTests {

    @Test("Empty SSE priming events are detected")
    func emptySSEPrimingEvent() {
        let event = Data("id: 1_1\ndata: \n\n".utf8)

        #expect(isEmptySSEPrimingEvent(event))
    }

    @Test("Empty SSE priming events can include retry")
    func emptySSEPrimingEventWithRetry() {
        let event = Data("id: 1_1\nretry: 1000\ndata: \n\n".utf8)

        #expect(isEmptySSEPrimingEvent(event))
    }

    @Test("JSON-RPC SSE messages are preserved")
    func jsonRPCSSEMessage() {
        let event = Data(#"id: 1_2\nevent: message\ndata: {"jsonrpc":"2.0","id":1,"result":{}}\n\n"#.utf8)

        #expect(!isEmptySSEPrimingEvent(event))
    }

    @Test("Data-only empty SSE events are preserved")
    func dataOnlyEmptySSEEvent() {
        let event = Data("data: \n\n".utf8)

        #expect(!isEmptySSEPrimingEvent(event))
    }
}
