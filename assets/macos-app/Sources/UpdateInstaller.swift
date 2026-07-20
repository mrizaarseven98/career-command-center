import Darwin
import Foundation

@main
struct CareerCommandCenterUpdateInstaller {
    static func main() {
        do {
            try install()
        } catch {
            writeLog("Update failed: \(error.localizedDescription)")
            exit(1)
        }
    }

    private static func install() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 4, let parentPID = Int32(arguments[3]) else {
            throw InstallerError.invalidArguments
        }
        let staged = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let destination = URL(fileURLWithPath: arguments[2], isDirectory: true)
        guard staged.lastPathComponent == "Career Command Center.app",
              destination.lastPathComponent == "Career Command Center.app" else {
            throw InstallerError.invalidBundlePath
        }
        try waitForExit(parentPID)

        let fileManager = FileManager.default
        let backup = destination.deletingLastPathComponent()
            .appendingPathComponent(".Career Command Center.backup-\(UUID().uuidString).app", isDirectory: true)
        var movedExisting = false
        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.moveItem(at: destination, to: backup)
                movedExisting = true
            }
            try fileManager.copyItem(at: staged, to: destination)
            try verify(destination)
            if movedExisting { try? fileManager.removeItem(at: backup) }
            let stagingContainer = staged.deletingLastPathComponent()
            let cleanupRoot = stagingContainer.lastPathComponent == "Extracted"
                ? stagingContainer.deletingLastPathComponent()
                : stagingContainer
            try? fileManager.removeItem(at: cleanupRoot)
            writeLog("Installed \(bundleVersion(destination)) at \(destination.path)")

            if ProcessInfo.processInfo.environment["CAREER_COMMAND_CENTER_SKIP_RELAUNCH"] != "1" {
                let launch = Process()
                launch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                launch.arguments = [destination.path]
                try launch.run()
            }
        } catch let installationError {
            do {
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                if movedExisting, fileManager.fileExists(atPath: backup.path) {
                    try fileManager.moveItem(at: backup, to: destination)
                }
            } catch let rollbackError {
                throw InstallerError.rollbackFailed(
                    backupPath: backup.path,
                    detail: rollbackError.localizedDescription
                )
            }
            throw installationError
        }
    }

    private static func waitForExit(_ pid: Int32) throws {
        let deadline = Date().addingTimeInterval(30)
        while kill(pid, 0) == 0 && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.2)
        }
        if kill(pid, 0) == 0 {
            throw InstallerError.applicationStillRunning
        }
    }

    private static func verify(_ app: URL) throws {
        let executable = app.appendingPathComponent("Contents/MacOS/CareerCommandCenter")
        let updater = app.appendingPathComponent("Contents/Helpers/CareerCommandCenterUpdater")
        let runner = app.appendingPathComponent("Contents/Helpers/CareerCommandCenterRunner")
        guard FileManager.default.isExecutableFile(atPath: executable.path),
              FileManager.default.isExecutableFile(atPath: updater.path),
              FileManager.default.isExecutableFile(atPath: runner.path) else {
            throw InstallerError.missingExecutable
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--deep", "--strict", app.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw InstallerError.invalidSignature }
    }

    private static func bundleVersion(_ app: URL) -> String {
        let info = app.appendingPathComponent("Contents/Info.plist")
        return (NSDictionary(contentsOf: info)?["CFBundleShortVersionString"] as? String) ?? "unknown version"
    }

    private static func writeLog(_ message: String) {
        let fileManager = FileManager.default
        let directory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Career Command Center", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        let url = directory.appendingPathComponent("update.log")
        if let handle = try? FileHandle(forWritingTo: url) {
            try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private enum InstallerError: LocalizedError {
        case invalidArguments
        case invalidBundlePath
        case missingExecutable
        case invalidSignature
        case applicationStillRunning
        case rollbackFailed(backupPath: String, detail: String)

        var errorDescription: String? {
            switch self {
            case .invalidArguments: return "The update installer received invalid arguments."
            case .invalidBundlePath: return "The update bundle path is invalid."
            case .missingExecutable: return "The updated app executable is missing."
            case .invalidSignature: return "The updated app signature is invalid."
            case .applicationStillRunning: return "The app did not close in time. The update was not installed."
            case .rollbackFailed(let backupPath, let detail):
                return "The update failed and the original app could not be restored automatically. The backup remains at \(backupPath). \(detail)"
            }
        }
    }
}
