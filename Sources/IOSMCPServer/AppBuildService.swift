import Foundation
import MCP

struct ResolvedAppBuild: Sendable {
    let build: SavedAppBuild
    let source: String
}

struct AppBuildArgumentKeys: Sendable {
    let projectPath: String
    let scheme: String
    let isWorkspace: String
    let workspaceRoot: String

    init(
        projectPath: String,
        scheme: String,
        isWorkspace: String,
        workspaceRoot: String = "workspace_root"
    ) {
        self.projectPath = projectPath
        self.scheme = scheme
        self.isWorkspace = isWorkspace
        self.workspaceRoot = workspaceRoot
    }
}

func clientWorkspaceRoots(from server: Server) async -> [URL] {
    do {
        let roots = try await withTimeout(seconds: 3) {
            try await server.listRoots()
        }

        return roots.compactMap { root in
            guard let url = URL(string: root.uri), url.isFileURL else { return nil }
            return url
        }
    } catch {
        return []
    }
}

func resolveAppBuildConfiguration(
    args: [String: Value]?,
    keys: AppBuildArgumentKeys,
    saved: SavedAppBuild?,
    bundleId: String,
    deviceUdid: String,
    workspaceRoots: [URL]
) async throws -> ResolvedAppBuild? {
    let projectPath = args?.string(keys.projectPath) ?? ""
    let scheme = args?.string(keys.scheme) ?? ""
    let hasInlineConfig = !projectPath.isEmpty || !scheme.isEmpty

    if hasInlineConfig {
        guard !projectPath.isEmpty, !scheme.isEmpty else {
            throw SimctlError.commandFailed("\(keys.projectPath) and \(keys.scheme) must be provided together.")
        }

        return ResolvedAppBuild(
            build: SavedAppBuild(
                projectPath: projectPath,
                scheme: scheme,
                isWorkspace: args?.bool(keys.isWorkspace) ?? isWorkspacePath(projectPath)
            ),
            source: "inline"
        )
    }

    if let saved {
        return ResolvedAppBuild(build: saved, source: "saved")
    }

    let explicitRoot = args?.string(keys.workspaceRoot).map { URL(fileURLWithPath: $0) }
    let roots = ([explicitRoot].compactMap { $0 } + workspaceRoots).deduplicatedByPath()
    guard !roots.isEmpty else { return nil }

    if let discovered = try await XcodeProjectDiscovery().discover(
        bundleId: bundleId,
        deviceUdid: deviceUdid,
        roots: roots
    ) {
        return ResolvedAppBuild(build: discovered, source: "auto-discovered")
    }

    return nil
}

func buildAndInstallApp(
    project: String,
    scheme: String,
    isWorkspace: Bool,
    deviceUdid: String,
    simctl: SimctlService
) async throws -> String {
    let scratch = buildScratchDirectory(project: project, scheme: scheme)
    let derivedDataPath = scratch + "/DerivedData"
    let sourcePackagesPath = scratch + "/SourcePackages"

    let buildArgs = [
        "build",
        isWorkspace ? "-workspace" : "-project", project,
        "-scheme", scheme,
        "-destination", "platform=iOS Simulator,id=\(deviceUdid)",
        "-derivedDataPath", derivedDataPath,
        "-clonedSourcePackagesDirPath", sourcePackagesPath,
        "-quiet",
    ]

    let build = try await runProcess(executable: "/usr/bin/xcodebuild", arguments: buildArgs)
    if build.status != 0 {
        let lastLines = build.output.split(separator: "\n").suffix(20).joined(separator: "\n")
        throw SimctlError.commandFailed("Failed to build app:\n\(lastLines)")
    }

    let settingsArgs = [
        isWorkspace ? "-workspace" : "-project", project,
        "-scheme", scheme,
        "-destination", "platform=iOS Simulator,id=\(deviceUdid)",
        "-derivedDataPath", derivedDataPath,
        "-clonedSourcePackagesDirPath", sourcePackagesPath,
        "-showBuildSettings",
    ]

    let settings = try await runProcess(executable: "/usr/bin/xcodebuild", arguments: settingsArgs)
    if settings.status != 0 {
        let lastLines = settings.output.split(separator: "\n").suffix(20).joined(separator: "\n")
        throw SimctlError.commandFailed("Failed to inspect built app settings:\n\(lastLines)")
    }

    guard let appPath = appPath(fromBuildSettings: settings.output) else {
        throw SimctlError.commandFailed("Could not locate built app product in xcodebuild settings output.")
    }

    guard FileManager.default.fileExists(atPath: appPath) else {
        throw SimctlError.commandFailed("Built app was not found at expected path: \(appPath)")
    }

    try await simctl.installApp(deviceUdid: deviceUdid, appPath: appPath)
    return appPath
}

private struct XcodeProjectDiscovery {
    func discover(bundleId: String, deviceUdid: String, roots: [URL]) async throws -> SavedAppBuild? {
        for candidate in projectCandidates(in: roots) {
            if !candidate.isWorkspace, !projectContainsBundleId(candidate.url, bundleId: bundleId) {
                continue
            }

            let schemes = try await schemes(for: candidate)
            for scheme in schemes {
                if try await schemeMatchesBundleId(
                    candidate,
                    scheme: scheme,
                    bundleId: bundleId,
                    deviceUdid: deviceUdid
                ) {
                    return SavedAppBuild(
                        projectPath: candidate.url.path,
                        scheme: scheme,
                        isWorkspace: candidate.isWorkspace
                    )
                }
            }
        }

        return nil
    }

    private func schemes(for candidate: XcodeProjectCandidate) async throws -> [String] {
        let args = [
            candidate.isWorkspace ? "-workspace" : "-project",
            candidate.url.path,
            "-list",
            "-json",
        ]

        let result = try await runProcess(executable: "/usr/bin/xcodebuild", arguments: args)
        guard result.status == 0,
              let data = result.output.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return []
        }

        let key = candidate.isWorkspace ? "workspace" : "project"
        guard let container = object[key] as? [String: Any],
              let schemes = container["schemes"] as? [String]
        else {
            return []
        }

        return schemes.sorted()
    }

    private func schemeMatchesBundleId(
        _ candidate: XcodeProjectCandidate,
        scheme: String,
        bundleId: String,
        deviceUdid: String
    ) async throws -> Bool {
        let args = [
            candidate.isWorkspace ? "-workspace" : "-project",
            candidate.url.path,
            "-scheme", scheme,
            "-destination", "platform=iOS Simulator,id=\(deviceUdid)",
            "-showBuildSettings",
        ]

        let result = try await runProcess(executable: "/usr/bin/xcodebuild", arguments: args)
        guard result.status == 0 else { return false }

        return result.output.split(separator: "\n").contains { line in
            line.trimmingCharacters(in: .whitespaces) == "PRODUCT_BUNDLE_IDENTIFIER = \(bundleId)"
        }
    }

    private func projectContainsBundleId(_ url: URL, bundleId: String) -> Bool {
        let pbxproj = url.appendingPathComponent("project.pbxproj")
        guard let contents = try? String(contentsOf: pbxproj, encoding: .utf8) else {
            return true
        }
        return contents.contains("PRODUCT_BUNDLE_IDENTIFIER = \(bundleId)")
    }
}

private struct XcodeProjectCandidate: Sendable {
    let url: URL
    let isWorkspace: Bool
}

private func projectCandidates(in roots: [URL]) -> [XcodeProjectCandidate] {
    var candidates: [XcodeProjectCandidate] = []

    for root in roots {
        let rootURL = root.resolvingSymlinksInPath()
        if let candidate = candidate(from: rootURL) {
            candidates.append(candidate)
            continue
        }

        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            continue
        }

        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if ["DerivedData", "Pods", ".build", ".swiftpm", ".git"].contains(name) {
                enumerator.skipDescendants()
                continue
            }

            guard relativeDepth(of: url, from: rootURL) <= 5 else {
                enumerator.skipDescendants()
                continue
            }

            if let candidate = candidate(from: url) {
                candidates.append(candidate)
                enumerator.skipDescendants()
            }
        }
    }

    return candidates
        .deduplicatedByPath { $0.url.path }
        .sorted {
            if $0.isWorkspace != $1.isWorkspace {
                return $0.isWorkspace
            }
            let leftDepth = $0.url.pathComponents.count
            let rightDepth = $1.url.pathComponents.count
            if leftDepth != rightDepth {
                return leftDepth < rightDepth
            }
            return $0.url.path < $1.url.path
        }
}

private func candidate(from url: URL) -> XcodeProjectCandidate? {
    if url.pathExtension == "xcworkspace" {
        return XcodeProjectCandidate(url: url, isWorkspace: true)
    } else if url.pathExtension == "xcodeproj" && url.lastPathComponent != "Pods.xcodeproj" {
        return XcodeProjectCandidate(url: url, isWorkspace: false)
    }
    return nil
}

private func relativeDepth(of url: URL, from root: URL) -> Int {
    let rootComponents = root.standardizedFileURL.pathComponents
    let urlComponents = url.standardizedFileURL.pathComponents
    return max(0, urlComponents.count - rootComponents.count)
}

func isWorkspacePath(_ path: String) -> Bool {
    path.hasSuffix(".xcworkspace")
}

private func appPath(fromBuildSettings output: String) -> String? {
    var builtProductsDir = ""
    var productName = ""

    for line in output.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("BUILT_PRODUCTS_DIR = ") {
            builtProductsDir = String(trimmed.dropFirst("BUILT_PRODUCTS_DIR = ".count))
        } else if trimmed.hasPrefix("FULL_PRODUCT_NAME = ") {
            productName = String(trimmed.dropFirst("FULL_PRODUCT_NAME = ".count))
        }
    }

    guard !builtProductsDir.isEmpty, !productName.isEmpty else { return nil }
    return builtProductsDir + "/" + productName
}

private func buildScratchDirectory(project: String, scheme: String) -> String {
    let raw = project + "-" + scheme
    let safe = raw.map { char -> Character in
        char.isLetter || char.isNumber ? char : "_"
    }
    let suffix = String(String(safe).suffix(80))
    return "/private/tmp/ios-mcp-build-\(suffix)"
}

private extension Array where Element == URL {
    func deduplicatedByPath() -> [URL] {
        var seen: Set<String> = []
        return filter { seen.insert($0.standardizedFileURL.path).inserted }
    }
}

private extension Array {
    func deduplicatedByPath(_ path: (Element) -> String) -> [Element] {
        var seen: Set<String> = []
        return filter { seen.insert(path($0)).inserted }
    }
}
