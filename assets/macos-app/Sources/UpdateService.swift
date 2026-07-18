import CryptoKit
import Foundation

struct SoftwareUpdate: Equatable {
    let version: String
    let tagName: String
    let releasePageURL: URL
    let archiveURL: URL
    let checksumURL: URL
    let notes: String
    let publishedAt: Date?
}

struct SoftwareReleaseCheck: Equatable {
    let latestVersion: String
    let releasePageURL: URL
    let publishedAt: Date?
    let update: SoftwareUpdate?
}

enum SoftwareUpdateState: Equatable {
    case idle
    case checking
    case current(version: String, checkedAt: Date)
    case available(SoftwareUpdate)
    case downloading(version: String)
    case installing(version: String)
    case failed(message: String, checkedAt: Date)
}

enum UpdateServiceError: LocalizedError, Equatable {
    case invalidResponse
    case releaseUnavailable
    case invalidRelease(String)
    case missingAsset(String)
    case checksumMismatch
    case extractionFailed
    case invalidBundle(String)
    case signatureInvalid

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "GitHub returned an invalid response."
        case .releaseUnavailable: return "The latest working release could not be reached."
        case .invalidRelease(let detail): return "The GitHub release is invalid: \(detail)"
        case .missingAsset(let name): return "The release is missing \(name)."
        case .checksumMismatch: return "The downloaded update failed checksum verification."
        case .extractionFailed: return "The downloaded update could not be extracted."
        case .invalidBundle(let detail): return "The downloaded app is invalid: \(detail)"
        case .signatureInvalid: return "The downloaded app failed its code-signature check."
        }
    }
}

struct UpdateService {
    static let repository = "mrizaarseven98/career-command-center"
    static let archiveAssetName = "Career-Command-Center-macOS.zip"
    static let checksumAssetName = "Career-Command-Center-macOS.zip.sha256"
    static let expectedBundleIdentifier = "com.careercommandcenter.macos"

    private let session: URLSession
    private let fileManager: FileManager

    init(session: URLSession = .shared, fileManager: FileManager = .default) {
        self.session = session
        self.fileManager = fileManager
    }

    func check(currentVersion: String) async throws -> SoftwareReleaseCheck {
        let override = ProcessInfo.processInfo.environment["CAREER_COMMAND_CENTER_UPDATE_API_URL"]
        let value = override ?? "https://api.github.com/repos/\(Self.repository)/releases/latest"
        guard let url = URL(string: value) else { throw UpdateServiceError.invalidResponse }
        var request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Career-Command-Center-macOS", forHTTPHeaderField: "User-Agent")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UpdateServiceError.invalidResponse }
        guard http.statusCode == 200 else { throw UpdateServiceError.releaseUnavailable }
        return try Self.parseRelease(data: data, currentVersion: currentVersion)
    }

    static func parseRelease(data: Data, currentVersion: String) throws -> SoftwareReleaseCheck {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload: GitHubReleasePayload
        do {
            payload = try decoder.decode(GitHubReleasePayload.self, from: data)
        } catch {
            throw UpdateServiceError.invalidRelease("metadata could not be decoded")
        }
        guard !payload.draft, !payload.prerelease else {
            throw UpdateServiceError.invalidRelease("latest release is not a stable release")
        }
        let latestVersion = normalizedVersion(payload.tagName)
        guard isValidVersion(latestVersion), let pageURL = URL(string: payload.htmlURL) else {
            throw UpdateServiceError.invalidRelease("tag or release URL is malformed")
        }

        guard compareVersions(latestVersion, currentVersion) == .orderedDescending else {
            return SoftwareReleaseCheck(
                latestVersion: latestVersion,
                releasePageURL: pageURL,
                publishedAt: payload.publishedAt,
                update: nil
            )
        }

        guard let archive = payload.assets.first(where: { $0.name == archiveAssetName }),
              let archiveURL = URL(string: archive.browserDownloadURL) else {
            throw UpdateServiceError.missingAsset(archiveAssetName)
        }
        guard let checksum = payload.assets.first(where: { $0.name == checksumAssetName }),
              let checksumURL = URL(string: checksum.browserDownloadURL) else {
            throw UpdateServiceError.missingAsset(checksumAssetName)
        }
        let update = SoftwareUpdate(
            version: latestVersion,
            tagName: payload.tagName,
            releasePageURL: pageURL,
            archiveURL: archiveURL,
            checksumURL: checksumURL,
            notes: payload.body,
            publishedAt: payload.publishedAt
        )
        return SoftwareReleaseCheck(
            latestVersion: latestVersion,
            releasePageURL: pageURL,
            publishedAt: payload.publishedAt,
            update: update
        )
    }

    func stage(_ update: SoftwareUpdate) async throws -> URL {
        let archiveData = try await download(update.archiveURL)
        let checksumData = try await download(update.checksumURL)
        guard let checksumText = String(data: checksumData, encoding: .utf8),
              let expected = checksumText.split(whereSeparator: { $0.isWhitespace }).first,
              expected.count == 64 else {
            throw UpdateServiceError.invalidRelease("checksum file is malformed")
        }
        let actual = Self.sha256(archiveData)
        guard actual.caseInsensitiveCompare(String(expected)) == .orderedSame else {
            throw UpdateServiceError.checksumMismatch
        }

        let stagingBase: URL
        if let override = ProcessInfo.processInfo.environment["CAREER_COMMAND_CENTER_UPDATE_STAGING_ROOT"],
           !override.isEmpty {
            stagingBase = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            stagingBase = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Career Command Center/Updates", isDirectory: true)
        }
        let root = stagingBase
            .appendingPathComponent("\(update.version)-\(UUID().uuidString)", isDirectory: true)
        let extraction = root.appendingPathComponent("Extracted", isDirectory: true)
        try fileManager.createDirectory(at: extraction, withIntermediateDirectories: true)
        let archive = root.appendingPathComponent(Self.archiveAssetName)
        try archiveData.write(to: archive, options: .atomic)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.path, extraction.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateServiceError.extractionFailed }

        let staged = try findApp(in: extraction)
        try validate(app: staged, expectedVersion: update.version)
        return staged
    }

    static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = versionComponents(lhs)
        let right = versionComponents(rhs)
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }

    static func normalizedVersion(_ value: String) -> String {
        var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.lowercased().hasPrefix("v") { cleaned.removeFirst() }
        return cleaned.split(separator: "+", maxSplits: 1).first.map(String.init) ?? cleaned
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func download(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 120)
        request.setValue("Career-Command-Center-macOS", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw UpdateServiceError.invalidResponse
        }
        return data
    }

    private func findApp(in root: URL) throws -> URL {
        if root.pathExtension == "app" { return root }
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { throw UpdateServiceError.extractionFailed }
        for case let url as URL in enumerator where url.lastPathComponent == "Career Command Center.app" {
            return url
        }
        throw UpdateServiceError.invalidBundle("Career Command Center.app was not found")
    }

    private func validate(app: URL, expectedVersion: String) throws {
        let infoURL = app.appendingPathComponent("Contents/Info.plist")
        guard let info = NSDictionary(contentsOf: infoURL) as? [String: Any],
              info["CFBundleIdentifier"] as? String == Self.expectedBundleIdentifier else {
            throw UpdateServiceError.invalidBundle("bundle identifier does not match")
        }
        let version = info["CFBundleShortVersionString"] as? String ?? ""
        guard Self.compareVersions(version, expectedVersion) == .orderedSame else {
            throw UpdateServiceError.invalidBundle("bundle version \(version) does not match release \(expectedVersion)")
        }
        let executable = app.appendingPathComponent("Contents/MacOS/CareerCommandCenter")
        let helper = app.appendingPathComponent("Contents/Helpers/CareerCommandCenterUpdater")
        guard fileManager.isExecutableFile(atPath: executable.path),
              fileManager.isExecutableFile(atPath: helper.path) else {
            throw UpdateServiceError.invalidBundle("required executable is missing")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--deep", "--strict", app.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateServiceError.signatureInvalid }
    }

    private static func isValidVersion(_ value: String) -> Bool {
        let components = versionComponents(value)
        return components.count >= 2 && !components.isEmpty
    }

    private static func versionComponents(_ value: String) -> [Int] {
        guard let core = normalizedVersion(value)
            .split(separator: "-", maxSplits: 1)
            .first else { return [] }
        let segments = core.split(separator: ".", omittingEmptySubsequences: false)
        guard !segments.isEmpty,
              segments.allSatisfy({ !$0.isEmpty && Int($0) != nil }) else { return [] }
        return segments.compactMap { Int($0) }
    }
}

private struct GitHubReleasePayload: Decodable {
    let tagName: String
    let htmlURL: String
    let body: String
    let draft: Bool
    let prerelease: Bool
    let publishedAt: Date?
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
        case draft
        case prerelease
        case publishedAt = "published_at"
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
