import Foundation

@main
@MainActor
struct PerformanceTests {
    static func main() throws {
        try testDateAndLeadFilteringPerformance()
        try testStartupDoesNotWaitForLaunchctl()
        print("Performance tests passed")
    }

    private static func testDateAndLeadFilteringPerformance() throws {
        let timestamp = "2026-07-20T08:15:30.123Z"
        var checksum = 0
        let parseStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<50_000 {
            if LeadDateFormatting.parse(timestamp) != nil { checksum += 1 }
        }
        let parseDuration = CFAbsoluteTimeGetCurrent() - parseStart
        try expect(checksum == 50_000, "cached timestamps remain valid")
        try expect(parseDuration < 5, "repeated timestamp parsing stays below five seconds")

        let store = AppStore(
            workspaceOverride: FileManager.default.temporaryDirectory,
            preview: true
        )
        store.state.leads = (0..<400).map { index in
            LeadRecord(raw: [
                "id": .string("performance-lead-\(index)"),
                "title": .string("Biomedical Engineer \(index)"),
                "organization": .string("Test Organization"),
                "location": .string("Zurich"),
                "type": .string(index.isMultiple(of: 5) ? "PhD" : "Job"),
                "status": .string(index.isMultiple(of: 7) ? "monitor" : "to_apply"),
                "discovered_at": .string(timestamp),
                "updated_at": .string(timestamp),
                "score": .integer(70 + index % 30),
                "match_strengths": .array([.string("Finite-element modelling and Python validation")])
            ])
        }
        store.selectSection(.new)
        store.setDateFilter(.all)
        _ = store.visibleLeads

        checksum = 0
        let filteringStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<250 {
            checksum += store.visibleLeads.count
        }
        let filteringDuration = CFAbsoluteTimeGetCurrent() - filteringStart
        try expect(checksum == 100_000, "lead filtering returns a stable result")
        try expect(filteringDuration < 5, "repeated filtering and sorting stays below five seconds")
        print(String(format: "Performance: date cache %.3fs, lead filtering %.3fs", parseDuration, filteringDuration))
    }

    private static func testStartupDoesNotWaitForLaunchctl() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("career-command-center-startup-performance-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let fakeLaunchctl = root.appendingPathComponent("slow-launchctl")
        try "#!/bin/sh\nsleep 1\nexit 1\n".write(to: fakeLaunchctl, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeLaunchctl.path)
        setenv("CAREER_COMMAND_CENTER_LAUNCHCTL_EXECUTABLE", fakeLaunchctl.path, 1)

        let start = CFAbsoluteTimeGetCurrent()
        let store = AppStore(workspaceOverride: root)
        let duration = CFAbsoluteTimeGetCurrent() - start
        try expect(store.workspaceURL == root, "performance fixture opens the requested workspace")
        try expect(duration < 0.5, "startup does not wait for launchctl")

        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        unsetenv("CAREER_COMMAND_CENTER_LAUNCHCTL_EXECUTABLE")
        print(String(format: "Performance: startup with slow launchctl %.3fs", duration))
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestFailure(message: message) }
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}
