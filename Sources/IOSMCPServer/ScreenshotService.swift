import Foundation

struct ScreenshotResult: Sendable {
    let base64: String
    let width: Int
    let height: Int
    let deviceName: String
    let filePath: String
}

actor ScreenshotService {
    private let simctl: SimctlService

    init(simctl: SimctlService) {
        self.simctl = simctl
    }

    func captureScreenshot(deviceUdid: String, savePath: String? = nil) async throws -> ScreenshotResult {
        let filePath = try await simctl.takeScreenshot(deviceUdid: deviceUdid, savePath: savePath)

        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let base64 = data.base64EncodedString()

        let (width, height) = await getImageDimensions(filePath)

        let devices = try await simctl.listDevices()
        let deviceName = devices.first(where: { $0.udid == deviceUdid })?.name ?? "Unknown"

        if savePath == nil {
            try? FileManager.default.removeItem(atPath: filePath)
        }

        return ScreenshotResult(
            base64: base64,
            width: width,
            height: height,
            deviceName: deviceName,
            filePath: filePath
        )
    }

    private func getImageDimensions(_ filePath: String) async -> (Int, Int) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        process.arguments = ["-g", "pixelWidth", "-g", "pixelHeight", filePath]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            await process.waitUntilExitAsync()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            let widthPattern = #"pixelWidth:\s*(\d+)"#
            let heightPattern = #"pixelHeight:\s*(\d+)"#

            var width = 0, height = 0

            if let match = output.range(of: widthPattern, options: .regularExpression) {
                let val = output[match].split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? "0"
                width = Int(val) ?? 0
            }
            if let match = output.range(of: heightPattern, options: .regularExpression) {
                let val = output[match].split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? "0"
                height = Int(val) ?? 0
            }

            return (width, height)
        } catch {
            return (0, 0)
        }
    }
}
