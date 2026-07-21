import Darwin
import Foundation

struct CareerCommandCenterScheduledRunner {
    static func run(arguments: [String]) {
        do {
            guard let command = arguments.first else { throw RunnerError.invalidArguments }
            switch command {
            case "run":
                try runSearch(Array(arguments.dropFirst()))
            case "schedule":
                try manageSchedule(Array(arguments.dropFirst()))
            default:
                throw RunnerError.invalidArguments
            }
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            Darwin.exit(1)
        }
    }

    private static func runSearch(_ rawArguments: [String]) throws {
        let values = try parsedValues(rawArguments)
        let workspace = try requiredURL("workspace", values)
        let provider = try required("provider", values)
        let assistant = try requiredURL("assistant-executable", values)
        let promptFile = try requiredURL("prompt-file", values)
        let runtimeDirectory = values["runtime-directory"].map(URL.init(fileURLWithPath:))
            ?? workspace.appendingPathComponent("Automation", isDirectory: true)
        guard ["codex", "claude"].contains(provider),
              FileManager.default.isExecutableFile(atPath: assistant.path),
              FileManager.default.fileExists(atPath: promptFile.path) else {
            throw RunnerError.invalidArguments
        }

        let logsDirectory = runtimeDirectory.appendingPathComponent("Logs", isDirectory: true)
        try FileManager.default.createDirectory(at: runtimeDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        let lockURL = runtimeDirectory.appendingPathComponent("search-run.lock")
        let lockDescriptor = Darwin.open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard lockDescriptor >= 0 else { throw RunnerError.lockUnavailable }
        defer {
            flock(lockDescriptor, LOCK_UN)
            Darwin.close(lockDescriptor)
        }
        guard flock(lockDescriptor, LOCK_EX | LOCK_NB) == 0 else {
            try writeRuntime(
                at: runtimeDirectory,
                state: "skipped",
                provider: provider,
                logPath: "",
                exitCode: nil,
                message: "Another Career Command Center search is already running."
            )
            return
        }

        let prompt = try String(contentsOf: promptFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { throw RunnerError.emptyPrompt }

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let logURL = logsDirectory.appendingPathComponent("scheduled-run-\(stamp).log")
        guard FileManager.default.createFile(atPath: logURL.path, contents: nil),
              let logHandle = try? FileHandle(forWritingTo: logURL) else {
            throw RunnerError.logUnavailable
        }
        defer { try? logHandle.close() }
        try logHandle.write(contentsOf: Data("Career Command Center scheduled run\nProvider: \(provider)\nWorkspace: \(workspace.path)\n\n".utf8))

        try writeRuntime(
            at: runtimeDirectory,
            state: "running",
            provider: provider,
            logPath: logURL.path,
            exitCode: nil,
            message: "The scheduled search is running."
        )

        let process = Process()
        process.executableURL = assistant
        process.currentDirectoryURL = runtimeDirectory
        if provider == "claude" {
            process.arguments = [
                "--print",
                "--permission-mode", "auto",
                "--effort", "high",
                "--add-dir", workspace.path,
                "--name", "Career Command Center Scheduled Search",
                prompt
            ]
        } else {
            process.arguments = [
                "--search",
                "-c", "approval_policy=\"never\"",
                "--sandbox", "workspace-write",
                "--add-dir", workspace.path,
                "-C", runtimeDirectory.path,
                "exec",
                "--skip-git-repo-check",
                prompt
            ]
        }
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        environment["HOME"] = home
        environment["PATH"] = [
            assistant.deletingLastPathComponent().path,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ].joined(separator: ":")
        environment["CAREER_COMMAND_CENTER_SCHEDULED_RUN"] = "1"
        process.environment = environment
        process.standardOutput = logHandle
        process.standardError = logHandle
        try process.run()
        process.waitUntilExit()

        let exitCode = process.terminationStatus
        try writeRuntime(
            at: runtimeDirectory,
            state: exitCode == 0 ? "completed" : "failed",
            provider: provider,
            logPath: logURL.path,
            exitCode: exitCode,
            message: exitCode == 0
                ? "The scheduled search completed."
                : "The scheduled search exited with code \(exitCode)."
        )
        Darwin.exit(exitCode)
    }

    private static func manageSchedule(_ rawArguments: [String]) throws {
        guard let action = rawArguments.first else { throw RunnerError.invalidArguments }
        let values = try parsedValues(Array(rawArguments.dropFirst()))
        let label = values["label"] ?? LocalScheduleService.defaultLabel
        let service = LocalScheduleService()

        switch action {
        case "install":
            let workspace = try requiredURL("workspace", values)
            let provider = try required("provider", values)
            let assistant = try requiredURL("assistant-executable", values)
            let promptFile = try requiredURL("prompt-file", values)
            let frequency = try required("frequency", values)
            let hour = try requiredInt("hour", values)
            let minute = try requiredInt("minute", values)
            let scheduledExecutable = values["scheduled-executable"].map(URL.init(fileURLWithPath:))
                ?? URL(fileURLWithPath: CommandLine.arguments[0])
            let configuration = LocalScheduleConfiguration(
                label: label,
                workspaceURL: workspace,
                provider: provider,
                assistantExecutableURL: assistant,
                runnerExecutableURL: scheduledExecutable,
                promptFileURL: promptFile,
                frequency: frequency,
                weekdaysOnly: values["weekdays-only"] == "true",
                weeklyDay: values["weekly-day"] ?? "Monday",
                hour: hour,
                minute: minute
            )
            try service.install(configuration)
            printStatus(service.status(label: label))
        case "remove":
            try service.remove(label: label)
            printStatus(service.status(label: label))
        case "status":
            printStatus(service.status(label: label))
        case "run-now":
            try service.startNow(label: label)
            printStatus(service.status(label: label))
        default:
            throw RunnerError.invalidArguments
        }
    }

    private static func parsedValues(_ arguments: [String]) throws -> [String: String] {
        var values: [String: String] = [:]
        var index = 0
        while index < arguments.count {
            let key = arguments[index]
            guard key.hasPrefix("--") else { throw RunnerError.invalidArguments }
            let name = String(key.dropFirst(2))
            if name == "weekdays-only" {
                values[name] = "true"
                index += 1
                continue
            }
            guard index + 1 < arguments.count else { throw RunnerError.invalidArguments }
            values[name] = arguments[index + 1]
            index += 2
        }
        return values
    }

    private static func required(_ key: String, _ values: [String: String]) throws -> String {
        guard let value = values[key], !value.isEmpty else { throw RunnerError.invalidArguments }
        return value
    }

    private static func requiredURL(_ key: String, _ values: [String: String]) throws -> URL {
        URL(fileURLWithPath: try required(key, values))
    }

    private static func requiredInt(_ key: String, _ values: [String: String]) throws -> Int {
        guard let value = Int(try required(key, values)) else { throw RunnerError.invalidArguments }
        return value
    }

    private static func writeRuntime(
        at runtimeDirectory: URL,
        state: String,
        provider: String,
        logPath: String,
        exitCode: Int32?,
        message: String
    ) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        var payload: [String: Any] = [
            "version": 1,
            "state": state,
            "provider": provider,
            "updated_at": now,
            "log_path": logPath,
            "message": message,
            "pid": ProcessInfo.processInfo.processIdentifier
        ]
        if state == "running" { payload["started_at"] = now }
        if ["completed", "failed", "skipped", "stopped"].contains(state) {
            payload["finished_at"] = now
        }
        if let exitCode { payload["exit_code"] = Int(exitCode) }
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(
            to: runtimeDirectory.appendingPathComponent("scheduler_runtime.json"),
            options: .atomic
        )
    }

    private static func printStatus(_ status: LocalScheduleStatus) {
        let payload: [String: Any] = [
            "installed": status.installed,
            "loaded": status.loaded,
            "running": status.running,
            "label": status.label,
            "launch_agent_path": status.launchAgentPath,
            "detail": status.detail
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) {
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
    }

    private enum RunnerError: LocalizedError {
        case invalidArguments
        case lockUnavailable
        case emptyPrompt
        case logUnavailable

        var errorDescription: String? {
            switch self {
            case .invalidArguments: return "The background runner received invalid arguments."
            case .lockUnavailable: return "The search-run lock could not be opened."
            case .emptyPrompt: return "The scheduled search prompt is empty."
            case .logUnavailable: return "The scheduled run log could not be created."
            }
        }
    }
}
