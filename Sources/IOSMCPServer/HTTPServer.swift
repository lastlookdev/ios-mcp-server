import Foundation
import MCP
@preconcurrency import NIOCore
@preconcurrency import NIOPosix
@preconcurrency import NIOHTTP1

package actor MCPHTTPServer {
    private let host: String
    private let port: Int
    private let endpoint: String
    private let serverFactory: @Sendable () async throws -> Server
    private var channel: Channel?
    private var sessions: [String: SessionContext] = [:]

    struct SessionContext {
        let server: Server
        let transport: StatefulHTTPServerTransport
        var lastAccessedAt: Date
    }

    package init(
        host: String = "127.0.0.1",
        port: Int = 9741,
        endpoint: String = "/mcp",
        serverFactory: @escaping @Sendable () async throws -> Server
    ) {
        self.host = host
        self.port = port
        self.endpoint = endpoint
        self.serverFactory = serverFactory
    }

    package func start() async throws {
        let endpoint = self.endpoint
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(Handler(server: self, endpoint: endpoint))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

        let channel = try await bootstrap.bind(host: host, port: port).get()
        self.channel = channel
        fputs("iOS MCP server running at http://\(host):\(port)\(endpoint)\n", stderr)
        try await channel.closeFuture.get()
    }

    func stop() async {
        for (_, session) in sessions {
            await session.transport.disconnect()
        }
        sessions.removeAll()
        try? await channel?.close()
        channel = nil
    }

    func handleRequest(_ request: HTTPRequest) async -> HTTPResponse {
        let sessionID = request.header(HTTPHeaderName.sessionID)

        if let sessionID, var session = sessions[sessionID] {
            session.lastAccessedAt = Date()
            sessions[sessionID] = session
            let response = await session.transport.handleRequest(request)
            if request.method.uppercased() == "DELETE" && response.statusCode == 200 {
                sessions.removeValue(forKey: sessionID)
            }
            return response
        }

        if request.method.uppercased() == "POST",
           let body = request.body,
           isInitializeRequest(body)
        {
            return await createSession(request)
        }

        return .error(statusCode: 400, .invalidRequest("Missing session or not an initialize request"))
    }

    private func isInitializeRequest(_ body: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return false }
        return json["method"] as? String == "initialize"
    }

    private func createSession(_ request: HTTPRequest) async -> HTTPResponse {
        let sessionID = UUID().uuidString

        struct FixedID: SessionIDGenerator {
            let id: String
            func generateSessionID() -> String { id }
        }

        let transport = StatefulHTTPServerTransport(
            sessionIDGenerator: FixedID(id: sessionID)
        )

        do {
            let server = try await serverFactory()
            try await server.start(transport: transport)
            sessions[sessionID] = SessionContext(
                server: server,
                transport: transport,
                lastAccessedAt: Date()
            )
            return await transport.handleRequest(request)
        } catch {
            await transport.disconnect()
            return .error(statusCode: 500, .internalError("Failed to create session: \(error)"))
        }
    }
}

// MARK: - NIO Handler

private final class Handler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let server: MCPHTTPServer
    private let endpoint: String
    private var head: HTTPRequestHead?
    private var body = Data()

    init(server: MCPHTTPServer, endpoint: String) {
        self.server = server
        self.endpoint = endpoint
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)
        switch part {
        case .head(let h):
            head = h
            body = Data()
        case .body(var buffer):
            if let bytes = buffer.readBytes(length: buffer.readableBytes) {
                body.append(contentsOf: bytes)
            }
        case .end:
            guard let head else { return }
            let path = String(head.uri.split(separator: "?").first ?? Substring(head.uri))

            guard path == endpoint else {
                let response = HTTPResponseHead(version: head.version, status: .notFound)
                context.write(wrapOutboundOut(.head(response)), promise: nil)
                context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
                return
            }

            var headers: [String: String] = [:]
            for (name, value) in head.headers {
                headers[name] = value
            }

            let httpRequest = HTTPRequest(
                method: head.method.rawValue,
                headers: headers,
                body: body.isEmpty ? nil : body
            )

            let version = head.version
            nonisolated(unsafe) let ctx = context
            Task {
                let response = await server.handleRequest(httpRequest)
                await self.writeResponse(response, version: version, context: ctx)
            }
        }
    }

    private func writeResponse(
        _ response: HTTPResponse,
        version: HTTPVersion,
        context: ChannelHandlerContext
    ) async {
        nonisolated(unsafe) let ctx = context
        let eventLoop = ctx.eventLoop

        switch response {
        case .stream(let stream, _):
            eventLoop.execute {
                var head = HTTPResponseHead(version: version, status: HTTPResponseStatus(statusCode: response.statusCode))
                for (name, value) in response.headers {
                    head.headers.add(name: name, value: value)
                }
                ctx.write(self.wrapOutboundOut(.head(head)), promise: nil)
                ctx.flush()
            }

            do {
                for try await chunk in stream {
                    eventLoop.execute {
                        var buffer = ctx.channel.allocator.buffer(capacity: chunk.count)
                        buffer.writeBytes(chunk)
                        ctx.writeAndFlush(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
                    }
                }
            } catch {}

            eventLoop.execute {
                ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
            }

        default:
            let bodyData = response.bodyData
            eventLoop.execute {
                var head = HTTPResponseHead(version: version, status: HTTPResponseStatus(statusCode: response.statusCode))
                for (name, value) in response.headers {
                    head.headers.add(name: name, value: value)
                }
                ctx.write(self.wrapOutboundOut(.head(head)), promise: nil)
                if let body = bodyData {
                    var buffer = ctx.channel.allocator.buffer(capacity: body.count)
                    buffer.writeBytes(body)
                    ctx.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
                }
                ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
            }
        }
    }
}
