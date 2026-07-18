import Foundation

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var payloads: [URL: Data] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let data = Self.payloads[url] else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Length": String(data.count)]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@main
struct UpdateStageTests {
    static func main() async throws {
        guard CommandLine.arguments.count == 2 else {
            throw StageFailure("Usage: update-stage-tests '/path/to/Career Command Center.app'")
        }
        let app = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let info = app.appendingPathComponent("Contents/Info.plist")
        guard let payload = NSDictionary(contentsOf: info) as? [String: Any],
              let version = payload["CFBundleShortVersionString"] as? String else {
            throw StageFailure("Could not read the fixture app version")
        }

        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("career-command-center-stage-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let archive = root.appendingPathComponent(UpdateService.archiveAssetName)

        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        zip.arguments = ["-c", "-k", "--keepParent", app.path, archive.path]
        try zip.run()
        zip.waitUntilExit()
        try expect(zip.terminationStatus == 0, "fixture app can be archived")

        let archiveData = try Data(contentsOf: archive)
        let archiveURL = URL(string: "https://updates.example.test/app.zip")!
        let checksumURL = URL(string: "https://updates.example.test/app.zip.sha256")!
        MockURLProtocol.payloads = [
            archiveURL: archiveData,
            checksumURL: Data("\(UpdateService.sha256(archiveData))  \(UpdateService.archiveAssetName)\n".utf8)
        ]
        setenv("CAREER_COMMAND_CENTER_UPDATE_STAGING_ROOT", root.appendingPathComponent("Updates").path, 1)
        defer { unsetenv("CAREER_COMMAND_CENTER_UPDATE_STAGING_ROOT") }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let service = UpdateService(session: URLSession(configuration: configuration))
        let update = SoftwareUpdate(
            version: version,
            tagName: "v\(version)",
            releasePageURL: URL(string: "https://updates.example.test/release")!,
            archiveURL: archiveURL,
            checksumURL: checksumURL,
            notes: "Fixture",
            publishedAt: nil
        )

        let staged = try await service.stage(update)
        try expect(staged.lastPathComponent == "Career Command Center.app", "archive extracts the expected app")
        try expect(
            fileManager.isExecutableFile(atPath: staged.appendingPathComponent("Contents/MacOS/CareerCommandCenter").path),
            "staged app includes its executable"
        )
        try expect(
            fileManager.isExecutableFile(atPath: staged.appendingPathComponent("Contents/Helpers/CareerCommandCenterUpdater").path),
            "staged app includes its updater"
        )

        MockURLProtocol.payloads[checksumURL] = Data((String(repeating: "0", count: 64) + "\n").utf8)
        do {
            _ = try await service.stage(update)
            throw StageFailure("A checksum mismatch was accepted")
        } catch let error as UpdateServiceError {
            try expect(error == .checksumMismatch, "checksum mismatch is rejected before extraction")
        }

        print("Update staging tests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw StageFailure(message) }
    }

    private struct StageFailure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = "Update staging test failed: \(description)" }
    }
}
