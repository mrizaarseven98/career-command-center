import Foundation

@main
@MainActor
struct CoreTests {
    static func main() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("career-command-center-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let stateDirectory = root.appendingPathComponent("State", isDirectory: true)
        try fileManager.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
        let stateURL = stateDirectory.appendingPathComponent("cv_command_center_state.json")
        let fixture: [String: Any] = [
            "version": 1,
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z",
            "notes": [],
            "leads": [
                [
                    "id": "hidden-lead",
                    "source_job_id": "source:hidden",
                    "title": "Hidden Role",
                    "organization": "Example A",
                    "status": "hidden",
                    "unknown_payload": ["preserve": true]
                ],
                [
                    "id": "manual-lead",
                    "source_job_id": "source:manual",
                    "title": "Manual Role",
                    "organization": "Example B",
                    "status": "manual_check",
                    "rationale": "Python validation work supports the analysis workflow.",
                    "concerns": "No direct GMP ownership is demonstrated; Upload transcripts and a degree certificate through the portal."
                ],
                [
                    "id": "active-lead",
                    "source_job_id": "source:active",
                    "title": "Active Role",
                    "organization": "Example C",
                    "status": "to_apply",
                    "score": 91
                ]
            ]
        ]
        let fixtureData = try JSONSerialization.data(withJSONObject: fixture, options: [.prettyPrinted])
        try fixtureData.write(to: stateURL)

        let store = AppStore(workspaceOverride: root)
        try expect(store.state.version == 3, "state migrates to version 3")
        try expect(store.state.leads.first(where: { $0.id == "hidden-lead" })?.status == .archived, "hidden migrates to archive")
        try expect(store.state.leads.first(where: { $0.id == "manual-lead" })?.status == .toApply, "manual check migrates to to_apply")
        try expect(store.state.leads.first(where: { $0.id == "hidden-lead" })?.raw["unknown_payload"] != nil, "unknown lead fields survive decoding")
        let migratedAssessment = store.state.leads.first(where: { $0.id == "manual-lead" })
        try expect(migratedAssessment?.matchStrengths.count == 1, "legacy rationale becomes match evidence")
        try expect(migratedAssessment?.fitGaps.contains(where: { $0.localizedCaseInsensitiveContains("GMP") }) == true, "genuine capability gap remains a fit gap")
        try expect(migratedAssessment?.applicationRequirements.contains(where: { $0.localizedCaseInsensitiveContains("transcript") }) == true, "submission documents become application requirements")
        try expect(migratedAssessment?.fitGaps.contains(where: { $0.localizedCaseInsensitiveContains("transcript") }) == false, "submission documents never remain fit gaps")
        try expect(migratedAssessment?.raw["assessment_schema_version"]?.intValue == 2, "assessment schema is versioned")

        try expect(store.config.search.countries.isEmpty, "fresh setup assumes no country")
        try expect(store.config.search.opportunityTypes.isEmpty, "fresh setup assumes no opportunity format")
        try expect(store.config.search.roleFamilies.isEmpty, "fresh setup assumes no profession")
        try expect(store.config.search.inferRoleFamilies, "fresh setup infers role families only after evidence intake")
        try expect(store.config.cv.targetLanguage == "Auto", "fresh setup chooses CV language per application")
        try expect(store.config.cv.includePhoto == false, "fresh setup assumes no photograph policy")
        try expect(store.config.automation.frequency == "manual" && !store.config.automation.enabled, "fresh setup does not schedule recurring searches")

        store.restoreArchived("hidden-lead")
        try expect(store.state.leads.first(where: { $0.id == "hidden-lead" })?.status == .toApply, "archive restore returns to active queue")

        store.deleteLead("active-lead")
        try expect(store.state.leads.contains(where: { $0.id == "active-lead" }) == false, "delete removes active record")
        try expect(store.state.deletedLeads.contains(where: { $0.id == "active-lead" }), "delete creates recoverable record")
        try expect(store.state.tombstones.contains(where: { $0.id == "active-lead" }), "delete creates dedupe tombstone")

        store.restoreDeleted("active-lead")
        try expect(store.state.leads.contains(where: { $0.id == "active-lead" }), "deleted record restores")
        try expect(store.state.tombstones.contains(where: { $0.id == "active-lead" }) == false, "restore removes tombstone")

        store.saveForLater("active-lead")
        store.archive("active-lead")
        store.restoreArchived("active-lead")
        try expect(store.state.leads.first(where: { $0.id == "active-lead" })?.status == .monitor, "archive restore returns to its original queue")
        try expect(store.selectedSection == .monitor, "archive restore opens the restored queue")

        store.markApplied("active-lead")
        try expect(store.state.leads.first(where: { $0.id == "active-lead" })?.appliedAt.isEmpty == false, "mark applied records a timestamp")
        store.moveToApply("active-lead")
        try expect(store.state.leads.first(where: { $0.id == "active-lead" })?.appliedAt.isEmpty == true, "leaving Applied clears the stale timestamp")

        store.archive("active-lead")
        store.deleteLead("active-lead")
        store.restoreDeleted("active-lead")
        try expect(store.state.leads.first(where: { $0.id == "active-lead" })?.status == .archived, "deleted archive record restores to Archive")
        try expect(store.selectedSection == .archive, "deleted archive restore opens Archive")
        store.restoreArchived("active-lead")

        store.deleteLead("active-lead")
        store.permanentlyDelete("active-lead")
        try expect(store.state.deletedLeads.contains(where: { $0.id == "active-lead" }) == false, "permanent delete removes details")
        try expect(store.state.tombstones.contains(where: { $0.id == "active-lead" }), "permanent delete retains dedupe marker")

        let reloaded = AppStore(workspaceOverride: root)
        try expect(reloaded.state.tombstones.contains(where: { $0.id == "active-lead" }), "tombstone persists after reload")
        try expect(reloaded.state.leads.first(where: { $0.id == "hidden-lead" })?.raw["unknown_payload"] != nil, "unknown data persists after save")

        reloaded.config.profile.fullName = "Test Candidate"
        reloaded.config.automation.needsCodexSync = false
        reloaded.config.search.includeKeywords = "validation"
        reloaded.saveConfig()
        var configData = try Data(contentsOf: reloaded.configURL)
        var config = try JSONDecoder().decode(AppConfig.self, from: configData)
        try expect(config.automation.needsCodexSync == false, "ordinary search settings are read at run time and do not dirty the schedule")

        reloaded.saveConfig(markAutomationDirty: true)
        configData = try Data(contentsOf: reloaded.configURL)
        config = try JSONDecoder().decode(AppConfig.self, from: configData)
        try expect(config.profile.fullName == "Test Candidate", "config persists")
        try expect(config.automation.needsCodexSync, "schedule changes mark Codex sync required")

        print("Core tests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestFailure(message: message) }
    }

    private struct TestFailure: Error, CustomStringConvertible {
        let message: String
        var description: String { "Test failed: \(message)" }
    }
}
