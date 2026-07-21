import Darwin
import Foundation

struct LocalScheduleConfiguration: Sendable {
    let label: String
    let workspaceURL: URL
    let provider: String
    let assistantExecutableURL: URL
    let runnerExecutableURL: URL
    let promptFileURL: URL
    let frequency: String
    let weekdaysOnly: Bool
    let weeklyDay: String
    let hour: Int
    let minute: Int
}

struct LocalScheduleStatus: Equatable, Sendable {
    var installed = false
    var loaded = false
    var running = false
    var label = LocalScheduleService.defaultLabel
    var launchAgentPath = ""
    var detail = "No recurring schedule is installed."
}

struct LocalScheduleService {
    static let defaultLabel = "com.careercommandcenter.search"

    private let fileManager: FileManager
    private let homeURL: URL
    private let launchctlURL: URL

    init(
        fileManager: FileManager = .default,
        homeURL: URL? = nil,
        launchctlURL: URL? = nil
    ) {
        self.fileManager = fileManager
        let environment = ProcessInfo.processInfo.environment
        self.homeURL = homeURL
            ?? environment["CAREER_COMMAND_CENTER_LAUNCH_AGENT_HOME"].map(URL.init(fileURLWithPath:))
            ?? fileManager.homeDirectoryForCurrentUser
        self.launchctlURL = launchctlURL
            ?? environment["CAREER_COMMAND_CENTER_LAUNCHCTL_EXECUTABLE"].map(URL.init(fileURLWithPath:))
            ?? URL(fileURLWithPath: "/bin/launchctl")
    }

    var domainTarget: String { "gui/\(getuid())" }

    func launchAgentURL(label: String = Self.defaultLabel) -> URL {
        homeURL
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    func runtimeDirectory(for workspaceURL: URL) -> URL {
        homeURL
            .appendingPathComponent("Library/Application Support/Career Command Center/Scheduler", isDirectory: true)
            .appendingPathComponent(Self.workspaceKey(workspaceURL), isDirectory: true)
    }

    static func workspaceKey(_ workspaceURL: URL) -> String {
        let path = workspaceURL.standardizedFileURL.path
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in path.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }

    func makeLaunchAgent(_ configuration: LocalScheduleConfiguration) throws -> [String: Any] {
        guard ["codex", "claude"].contains(configuration.provider) else {
            throw LocalScheduleError.invalidProvider
        }
        guard ["daily", "weekly"].contains(configuration.frequency),
              (0...23).contains(configuration.hour),
              (0...59).contains(configuration.minute) else {
            throw LocalScheduleError.invalidSchedule
        }
        guard fileManager.isExecutableFile(atPath: configuration.runnerExecutableURL.path) else {
            throw LocalScheduleError.missingRunner(configuration.runnerExecutableURL.path)
        }
        guard fileManager.isExecutableFile(atPath: configuration.assistantExecutableURL.path) else {
            throw LocalScheduleError.missingAssistant(configuration.assistantExecutableURL.path)
        }

        let intervals = try calendarIntervals(for: configuration)
        let runtime = runtimeDirectory(for: configuration.workspaceURL)
        let logs = runtime.appendingPathComponent("Logs", isDirectory: true)
        return [
            "Label": configuration.label,
            "ProgramArguments": [
                configuration.runnerExecutableURL.path,
                "--scheduled-run",
                "run",
                "--workspace", configuration.workspaceURL.path,
                "--provider", configuration.provider,
                "--assistant-executable", configuration.assistantExecutableURL.path,
                "--prompt-file", configuration.promptFileURL.path,
                "--runtime-directory", runtime.path
            ],
            "WorkingDirectory": runtime.path,
            "StartCalendarInterval": intervals,
            "RunAtLoad": false,
            "ProcessType": "Standard",
            "ThrottleInterval": 60,
            "StandardOutPath": logs.appendingPathComponent("scheduler-service.stdout.log").path,
            "StandardErrorPath": logs.appendingPathComponent("scheduler-service.stderr.log").path,
            "AssociatedBundleIdentifiers": ["com.careercommandcenter.macos"]
        ]
    }

    func install(_ configuration: LocalScheduleConfiguration) throws {
        let runtime = runtimeDirectory(for: configuration.workspaceURL)
        try fileManager.createDirectory(at: runtime, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: runtime.appendingPathComponent("Logs", isDirectory: true),
            withIntermediateDirectories: true
        )
        let destination = launchAgentURL(label: configuration.label)
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        let payload = try makeLaunchAgent(configuration)
        let data = try PropertyListSerialization.data(
            fromPropertyList: payload,
            format: .xml,
            options: 0
        )

        try? stop(label: configuration.label)
        _ = try runLaunchctl(["bootout", serviceTarget(configuration.label)], allowFailure: true)
        try data.write(to: destination, options: .atomic)
        let result = try runLaunchctl(["bootstrap", domainTarget, destination.path])
        guard result.exitCode == 0 else {
            throw LocalScheduleError.launchctlFailed(result.output)
        }
        _ = try runLaunchctl(["enable", serviceTarget(configuration.label)], allowFailure: true)
    }

    func remove(label: String = Self.defaultLabel) throws {
        try? stop(label: label)
        _ = try runLaunchctl(["bootout", serviceTarget(label)], allowFailure: true)
        let destination = launchAgentURL(label: label)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
    }

    func stop(label: String = Self.defaultLabel) throws {
        let printed = try runLaunchctl(["print", serviceTarget(label)], allowFailure: true)
        if let processID = serviceProcessID(from: printed.output) {
            let descendants = descendantProcessIDs(of: processID)
            for descendant in descendants.reversed() {
                Darwin.kill(descendant, SIGTERM)
            }
            if !descendants.isEmpty {
                usleep(300_000)
                for descendant in descendants where processExists(descendant) {
                    Darwin.kill(descendant, SIGKILL)
                }
            }
        }
        let result = try runLaunchctl(["kill", "SIGTERM", serviceTarget(label)], allowFailure: true)
        if result.exitCode != 0,
           !result.output.localizedCaseInsensitiveContains("no such process"),
           !result.output.localizedCaseInsensitiveContains("could not find service") {
            throw LocalScheduleError.launchctlFailed(result.output)
        }
    }

    func startNow(label: String = Self.defaultLabel) throws {
        let result = try runLaunchctl(["kickstart", serviceTarget(label)])
        guard result.exitCode == 0 else {
            throw LocalScheduleError.launchctlFailed(result.output)
        }
    }

    func status(label: String = Self.defaultLabel) -> LocalScheduleStatus {
        let destination = launchAgentURL(label: label)
        let installed = fileManager.fileExists(atPath: destination.path)
        guard let result = try? runLaunchctl(["print", serviceTarget(label)], allowFailure: true),
              result.exitCode == 0 else {
            return LocalScheduleStatus(
                installed: installed,
                loaded: false,
                running: false,
                label: label,
                launchAgentPath: destination.path,
                detail: installed ? "The schedule file exists but is not loaded by macOS." : "No recurring schedule is installed."
            )
        }
        let running = result.output.range(
            of: #"state\s*=\s*running"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        return LocalScheduleStatus(
            installed: installed,
            loaded: true,
            running: running,
            label: label,
            launchAgentPath: destination.path,
            detail: running ? "A scheduled search is running." : "The recurring schedule is loaded by macOS."
        )
    }

    private func calendarIntervals(for configuration: LocalScheduleConfiguration) throws -> Any {
        let base = ["Hour": configuration.hour, "Minute": configuration.minute]
        if configuration.frequency == "daily" {
            if configuration.weekdaysOnly {
                return (1...5).map { weekday in
                    ["Hour": configuration.hour, "Minute": configuration.minute, "Weekday": weekday]
                }
            }
            return base
        }

        guard let weekday = Self.weekdayNumber(configuration.weeklyDay) else {
            throw LocalScheduleError.invalidSchedule
        }
        return [
            "Hour": configuration.hour,
            "Minute": configuration.minute,
            "Weekday": weekday
        ]
    }

    static func weekdayNumber(_ value: String) -> Int? {
        [
            "Sunday": 0,
            "Monday": 1,
            "Tuesday": 2,
            "Wednesday": 3,
            "Thursday": 4,
            "Friday": 5,
            "Saturday": 6
        ][value]
    }

    private func serviceTarget(_ label: String) -> String {
        "\(domainTarget)/\(label)"
    }

    private func serviceProcessID(from output: String) -> Int32? {
        guard let match = output.range(
            of: #"(?m)^\s*pid\s*=\s*([0-9]+)\s*$"#,
            options: .regularExpression
        ) else { return nil }
        let line = String(output[match])
        return line.split(separator: "=").last
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap(Int32.init)
    }

    private func descendantProcessIDs(of parent: Int32) -> [Int32] {
        let pgrepURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        guard fileManager.isExecutableFile(atPath: pgrepURL.path) else { return [] }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = pgrepURL
        process.arguments = ["-P", String(parent)]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [] }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let children = String(decoding: data, as: UTF8.self)
            .split(whereSeparator: { $0.isWhitespace })
            .compactMap { Int32($0) }
        return children + children.flatMap(descendantProcessIDs)
    }

    private func processExists(_ processID: Int32) -> Bool {
        Darwin.kill(processID, 0) == 0 || errno == EPERM
    }

    private func runLaunchctl(
        _ arguments: [String],
        allowFailure: Bool = false
    ) throws -> (exitCode: Int32, output: String) {
        guard fileManager.isExecutableFile(atPath: launchctlURL.path) else {
            throw LocalScheduleError.launchctlUnavailable
        }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = launchctlURL
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if process.terminationStatus != 0 && !allowFailure {
            throw LocalScheduleError.launchctlFailed(output)
        }
        return (process.terminationStatus, output)
    }
}

enum LocalScheduleError: LocalizedError, Sendable {
    case invalidProvider
    case invalidSchedule
    case missingRunner(String)
    case missingAssistant(String)
    case launchctlUnavailable
    case launchctlFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidProvider:
            return "Choose Codex or Claude Code before saving the schedule."
        case .invalidSchedule:
            return "The selected recurring schedule is invalid."
        case .missingRunner(let path):
            return "The background runner is missing at \(path). Reinstall the app."
        case .missingAssistant(let path):
            return "The selected assistant executable is unavailable at \(path)."
        case .launchctlUnavailable:
            return "macOS background scheduling is unavailable."
        case .launchctlFailed(let detail):
            return detail.isEmpty
                ? "macOS could not register the recurring schedule."
                : "macOS could not register the recurring schedule: \(detail)"
        }
    }
}
