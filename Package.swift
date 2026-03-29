// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ios-mcp-server",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "IOSMCPServer",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
            ],
            resources: [
                .copy("Resources/Runner.zip"),
            ]
        ),
        .executableTarget(
            name: "ios-mcp-server",
            dependencies: [
                "IOSMCPServer",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "IOSMCPServerTests",
            dependencies: ["IOSMCPServer"]
        ),
    ]
)
