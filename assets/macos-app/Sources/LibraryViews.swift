import Combine
import Foundation
import SwiftUI

struct DocumentsView: View {
    @ObservedObject var store: AppStore
    @State private var categoryFilter: DocumentCategory?

    private var files: [DocumentItem] {
        guard let categoryFilter else { return store.documentItems }
        return store.documentItems.filter { $0.category == categoryFilter }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                SectionTitle(title: "Documents", subtitle: "Source material for evidence extraction and future applications")
                Spacer()
                Button { store.revealDocumentInbox() } label: {
                    Label("Open Folder", systemImage: "folder")
                }
                .buttonStyle(SecondaryButtonStyle())
                Menu {
                    ForEach(DocumentCategory.allCases) { category in
                        Button(category.rawValue) { store.importDocuments(category: category) }
                    }
                    Divider()
                    Button("Project Material") { store.importProjectFolder() }
                } label: {
                    Label("Import", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(22)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(DocumentCategory.allCases) { category in
                            Button {
                                categoryFilter = categoryFilter == category ? nil : category
                            } label: {
                                HStack(spacing: 11) {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(AppTheme.teal)
                                        .frame(width: 30, height: 30)
                                        .background(AppTheme.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(category.rawValue)
                                            .font(.system(size: 12, weight: .semibold))
                                            .lineLimit(1)
                                        Text("\(store.documentCount(for: category)) files")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(11)
                                .background(
                                    categoryFilter == category ? AppTheme.teal.opacity(0.09) : AppTheme.panel,
                                    in: RoundedRectangle(cornerRadius: 7)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(categoryFilter == category ? AppTheme.teal.opacity(0.35) : AppTheme.line)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        Text(categoryFilter?.rawValue ?? "All Files")
                            .font(.system(size: 14, weight: .semibold))
                        Text("\(files.count)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if categoryFilter != nil {
                            Button("Clear Filter") { categoryFilter = nil }
                                .buttonStyle(.plain)
                                .foregroundStyle(AppTheme.teal)
                        }
                    }

                    if files.isEmpty {
                        EmptyStateView(
                            icon: "folder.badge.plus",
                            title: "No documents in this category",
                            message: "Import source documents before asking \(store.assistantDisplayName) to audit evidence or build master CVs.",
                            actionTitle: "Import Documents",
                            action: {
                                store.importDocuments(category: categoryFilter ?? .other)
                            }
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(files) { file in
                                Button {
                                    store.open(path: file.url.path)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: file.category.icon)
                                            .foregroundStyle(AppTheme.teal)
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(file.name)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            Text(file.category.rawValue)
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(ByteCountFormatter.string(fromByteCount: file.byteCount, countStyle: .file))
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .frame(height: 48)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if file.id != files.last?.id { Divider() }
                            }
                        }
                        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.line))
                    }
                }
                .padding(22)
                .frame(maxWidth: 1050, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .background(AppTheme.canvas)
        .onAppear { store.refreshDocuments() }
    }
}

struct EvidenceView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SectionTitle(title: "Evidence", subtitle: "Facts, ownership boundaries, metrics, and project context")
                Spacer()
                Button("Open Evidence Bank") {
                    store.reveal(path: store.workspaceURL.appendingPathComponent("Evidence_Bank").path)
                }
                .buttonStyle(SecondaryButtonStyle())
                Button("Save Answers") {
                    store.saveEvidenceAnswers()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(22)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    InlineBanner(
                        kind: .info,
                        title: "Evidence changes CVs more than adjectives do",
                        message: "Update these answers whenever you recover a report, remember a constraint, verify a KPI, or clarify what you personally owned."
                    )

                    evidenceEditor(
                        title: "Education and experience",
                        subtitle: "Degrees, disciplines, employers, role scope, dates, and important transitions in plain factual language.",
                        text: $store.config.evidence.educationAndExperience
                    )
                    evidenceEditor(
                        title: "Career direction",
                        subtitle: "Work you want more of, work you want to avoid, and directions you are considering.",
                        text: $store.config.evidence.careerDirection
                    )
                    evidenceEditor(
                        title: "Strongest work",
                        subtitle: "Projects and roles you want to defend in an interview, including what made them difficult.",
                        text: $store.config.evidence.strongestWork
                    )
                    evidenceEditor(
                        title: "Personal ownership",
                        subtitle: "Your individual implementation, decisions, testing, analysis, and documentation.",
                        text: $store.config.evidence.ownershipBoundaries
                    )
                    evidenceEditor(
                        title: "Verified metrics",
                        subtitle: "State whether each figure is measured, estimated, proposed, or a scale descriptor.",
                        text: $store.config.evidence.verifiedMetrics
                    )
                    evidenceEditor(
                        title: "Project context",
                        subtitle: "Tools, constraints, failed approaches, team context, and engineering conclusions absent from reports.",
                        text: $store.config.evidence.projectContext
                    )
                    evidenceEditor(
                        title: "Role concerns",
                        subtitle: "Recurring gaps, relocation limits, permit constraints, and role families that should be treated cautiously.",
                        text: $store.config.evidence.roleConcerns
                    )
                    evidenceEditor(
                        title: "Claims to avoid",
                        subtitle: "Shared ownership, unverified dates, proposed KPIs, or technologies you did not personally use.",
                        text: $store.config.evidence.claimsToAvoid
                    )
                }
                .padding(22)
                .frame(maxWidth: 900, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .background(AppTheme.canvas)
    }

    private func evidenceEditor(title: String, subtitle: String, text: Binding<String>) -> some View {
        PanelSection(title: title, subtitle: subtitle) {
            TextEditor(text: text)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 105)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(AppTheme.line))
        }
    }
}

struct AutomationView: View {
    @ObservedObject var store: AppStore
    @State private var runStatus: AutomationRunStatus?
    private let runRefreshTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SectionTitle(title: "Automation", subtitle: "Local background schedule, search status, and package-generation policy")
                Spacer()
                if !store.visibleRunLogPath.isEmpty {
                    Button {
                        store.open(path: store.visibleRunLogPath)
                    } label: {
                        Label("Run Log", systemImage: "doc.text")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                if store.isAnySearchRunning {
                    Button {
                        store.stopSearchRun()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(DangerButtonStyle())
                } else {
                    Button {
                        store.runSearchNow()
                    } label: {
                        Label("Run Search Now", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(22)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if store.isAnySearchRunning {
                        InlineBanner(
                            kind: .info,
                            title: "\(store.assistantDisplayName) search is running",
                            message: store.isSearchRunInProgress
                                ? "The search was started from this app. The run log is available above; verified results appear after the run is recorded."
                                : "macOS started this search from the saved schedule. The app can be closed while it runs; progress and output are written to the run log."
                        )
                    }
                    if !store.config.automation.legacyAssistantAutomationID.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            InlineBanner(
                                kind: .warning,
                                title: "Disable the previous Codex schedule",
                                message: "An older Codex Scheduled task named \(store.config.automation.legacyAssistantAutomationID) may still run separately. Disable it once to prevent duplicate searches; new scheduling is handled directly by this app."
                            )
                            HStack {
                                Button("Open Codex Scheduled") { store.openCodexScheduled() }
                                    .buttonStyle(SecondaryButtonStyle())
                                Button("I Disabled It") { store.confirmLegacyAssistantScheduleDisabled() }
                                    .buttonStyle(PrimaryButtonStyle())
                            }
                        }
                    }
                    if store.config.automation.enabled
                        && store.config.automation.frequency != "manual"
                        && (store.config.automation.needsCodexSync || !store.localScheduleStatus.loaded) {
                        InlineBanner(
                            kind: .warning,
                            title: "Schedule setup required",
                            message: "The schedule has changed or is not loaded by macOS. Save it below to register the local \(store.assistantDisplayName) CLI runner."
                        )
                    } else if store.recurringScheduleIsActive {
                        InlineBanner(
                            kind: .success,
                            title: "Recurring schedule active",
                            message: "\(scheduleSummary). macOS runs \(store.assistantDisplayName) directly, even when this app window is closed. The Mac must be on and the user logged in."
                        )
                    } else {
                        InlineBanner(
                            kind: .info,
                            title: "Manual search mode",
                            message: "No recurring search is active. Run a search whenever you want from this screen or the sidebar."
                        )
                    }

                    if ["failed", "interrupted"].contains(store.scheduledRunRuntime.state) {
                        InlineBanner(
                            kind: .warning,
                            title: "Last background run needs attention",
                            message: store.scheduledRunRuntime.message.isEmpty
                                ? "Open the run log for details."
                                : store.scheduledRunRuntime.message
                        )
                    }

                    if let runStatus {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            metricTile(title: "Last run", value: runStatus.lastRunAt.isEmpty ? "Not yet" : runStatus.lastRunAt, icon: "clock")
                            metricTile(title: "New leads", value: String(runStatus.leadsAdded), icon: "plus.circle")
                            metricTile(title: "Packages", value: String(runStatus.packagesCreated), icon: "doc.on.doc")
                        }
                    }

                    PanelSection(title: "Schedule") {
                        VStack(alignment: .leading, spacing: 15) {
                            Picker("Run mode", selection: automationFrequency) {
                                Text("Manual only").tag("manual")
                                Text("Daily").tag("daily")
                                Text("Weekly").tag("weekly")
                            }
                            .pickerStyle(.segmented)
                            if store.config.automation.frequency != "manual" {
                                if store.config.automation.frequency == "daily" {
                                    Toggle("Weekdays only", isOn: $store.config.automation.weekdaysOnly)
                                        .toggleStyle(.switch)
                                } else {
                                    Picker("Day", selection: $store.config.automation.weeklyDay) {
                                        ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], id: \.self) {
                                            Text($0).tag($0)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                HStack(spacing: 20) {
                                    Stepper("Hour: \(String(format: "%02d", store.config.automation.hour))", value: $store.config.automation.hour, in: 0...23)
                                    Divider().frame(height: 22)
                                    Stepper("Minute: \(String(format: "%02d", store.config.automation.minute))", value: $store.config.automation.minute, in: 0...55, step: 5)
                                }
                            }
                            Stepper("Minimum new leads: \(store.config.automation.minimumNewLeads)", value: $store.config.automation.minimumNewLeads, in: 1...20)
                        }
                    }

                    PanelSection(title: "Search depth", subtitle: "The automation reads current countries, job categories, role families, and exclusions from Settings on every run.") {
                        VStack(alignment: .leading, spacing: 8) {
                            Slider(value: Binding(
                                get: { Double(store.config.automation.searchDepthMinutes) },
                                set: { store.config.automation.searchDepthMinutes = Int($0) }
                            ), in: 30...480, step: 30)
                            HStack {
                                Text(durationLabel(store.config.automation.searchDepthMinutes))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.teal)
                                Spacer()
                                Text("30 min")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Text("8 hr")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    PanelSection(title: "Document generation") {
                        Toggle("Create CV and cover-letter packages automatically for exceptional matches", isOn: $store.config.automation.autoCreateTierAPackages)
                            .toggleStyle(.switch)
                    }

                    HStack {
                        Spacer()
                        Button("Save Schedule") {
                            store.saveAutomationSchedule()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .padding(22)
                .frame(maxWidth: 900, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .background(AppTheme.canvas)
        .onAppear {
            store.refreshBackgroundAutomationState()
            refreshRunStatus()
        }
        .onReceive(runRefreshTimer) { _ in
            store.refreshScheduledRunRuntime()
            refreshRunStatus()
        }
        .onChange(of: scheduleFingerprint) { _, _ in
            store.markScheduleDraftDirty()
        }
    }

    private func metricTile(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.teal)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.line))
    }

    private func durationLabel(_ minutes: Int) -> String {
        let hours = Double(minutes) / 60
        if minutes < 60 { return "\(minutes) minutes per run" }
        return hours == floor(hours)
            ? "\(Int(hours)) hour\(hours == 1 ? "" : "s") per run"
            : String(format: "%.1f hours per run", hours)
    }

    private func refreshRunStatus() {
        let refreshed = AutomationRunStatus.load(from: store.automationStatusURL)
        if refreshed != runStatus { runStatus = refreshed }
    }

    private var scheduleSummary: String {
        let time = String(format: "%02d:%02d", store.config.automation.hour, store.config.automation.minute)
        if store.config.automation.frequency == "weekly" {
            return "Runs every \(store.config.automation.weeklyDay) at \(time)"
        }
        return store.config.automation.weekdaysOnly
            ? "Runs Monday to Friday at \(time)"
            : "Runs daily at \(time)"
    }

    private var scheduleFingerprint: String {
        [
            store.config.automation.frequency,
            String(store.config.automation.weekdaysOnly),
            store.config.automation.weeklyDay,
            String(store.config.automation.hour),
            String(store.config.automation.minute)
        ].joined(separator: "|")
    }

    private var automationFrequency: Binding<String> {
        Binding(
            get: { store.config.automation.frequency },
            set: { value in
                store.config.automation.frequency = value
                store.config.automation.enabled = value != "manual"
            }
        )
    }
}

private struct AutomationRunStatus: Codable, Equatable {
    var lastRunAt: String
    var leadsAdded: Int
    var packagesCreated: Int

    enum CodingKeys: String, CodingKey {
        case lastRunAt = "last_run_at"
        case leadsAdded = "leads_added"
        case packagesCreated = "packages_created"
    }

    static func load(from url: URL) -> AutomationRunStatus? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AutomationRunStatus.self, from: data)
    }
}

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @State private var tab: String

    init(store: AppStore, initialTab: String = "Profile") {
        self.store = store
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SectionTitle(title: "Settings", subtitle: "Profile, search scope, integration, workspace, and software")
                Spacer()
                if ["Profile", "Search", "CV"].contains(tab) {
                    Button("Save Changes") {
                        store.saveConfig()
                        store.showToast("Settings saved")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(22)
            Divider()

            VStack(spacing: 0) {
                Picker("Settings", selection: $tab) {
                    Text("Profile").tag("Profile")
                    Text("Search").tag("Search")
                    Text("CV").tag("CV")
                    Text("Integration").tag("Integration")
                    Text("App").tag("App")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 600)
                .padding(.vertical, 16)

                Divider()
                ScrollView {
                    settingsContent
                        .padding(22)
                        .frame(maxWidth: 900, alignment: .topLeading)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
        .background(AppTheme.canvas)
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch tab {
        case "Search": searchSettings
        case "CV": cvSettings
        case "Integration": integrationSettings
        case "App": applicationSettings
        default: profileSettings
        }
    }

    private var profileSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            PanelSection(title: "Contact and identity") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], alignment: .leading, spacing: 14) {
                    settingsField("Full name", text: $store.config.profile.fullName)
                    settingsField("Location", text: $store.config.profile.location)
                    settingsField("Email", text: $store.config.profile.email)
                    settingsField("Phone", text: $store.config.profile.phone)
                    settingsField("LinkedIn", text: $store.config.profile.linkedinURL)
                    settingsField("GitHub or portfolio", text: $store.config.profile.githubURL)
                }
            }
            PanelSection(title: "Locked application facts") {
                settingsField("Work authorisation", text: $store.config.profile.workAuthorization)
                settingsField("Languages", text: $store.config.profile.languages)
            }
        }
    }

    private var searchSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            PanelSection(title: "Geography", subtitle: "Locations the search should actually cover.") {
                settingsField("Countries", text: commaSeparated($store.config.search.countries))
            }
            PanelSection(title: "Opportunity types") {
                FlowLayout {
                    ForEach(OpportunityFormatOptions.common, id: \.self) { option in
                        ChoiceChip(title: option, selected: store.config.search.opportunityTypes.contains(option)) {
                            toggle(option, in: &store.config.search.opportunityTypes)
                        }
                    }
                }
                settingsField("Other formats", text: customOpportunityFormats)
            }
            PanelSection(title: "Working model", subtitle: "Leave all unselected if every arrangement is acceptable.") {
                FlowLayout {
                    ForEach(["On-site", "Hybrid", "Remote"], id: \.self) { option in
                        ChoiceChip(title: option, selected: store.config.search.workArrangements.contains(option)) {
                            toggle(option, in: &store.config.search.workArrangements)
                        }
                    }
                }
            }
            PanelSection(title: "Professional direction", subtitle: "No preset profession is assigned. Use evidence-led discovery or define your own role families.") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Infer suitable role families from my evidence", isOn: $store.config.search.inferRoleFamilies)
                        .toggleStyle(.switch)
                    settingsField("Direction in your own words", text: $store.config.search.targetRoleDescription)
                    if !store.config.search.inferRoleFamilies {
                        settingsField("Role families, comma-separated", text: commaSeparated($store.config.search.roleFamilies))
                    }
                }
            }
            PanelSection(title: "Seniority", subtitle: "Leave all unselected if posting-specific evidence should decide.") {
                FlowLayout {
                    ForEach(["Internship", "Graduate", "Junior", "Mid-level", "Senior", "Lead"], id: \.self) { option in
                        ChoiceChip(title: option, selected: store.config.search.seniority.contains(option)) {
                            toggle(option, in: &store.config.search.seniority)
                        }
                    }
                }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())]) {
                settingsField("Include keywords", text: $store.config.search.includeKeywords)
                settingsField("Exclude keywords", text: $store.config.search.excludeKeywords)
            }
            PanelSection(title: "Lead threshold", subtitle: "This score measures evidence fit. Upload requirements and application logistics never reduce it.") {
                Stepper("Minimum fit score: \(store.config.search.minimumScore)", value: $store.config.search.minimumScore, in: 60...98)
            }
        }
    }

    private var cvSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            InlineBanner(
                kind: .info,
                title: "Evidence-first strategy v\(store.config.cv.strategyVersion)",
                message: "Every application starts from a verified role-family master and passes content, ATS, duplication, and visual checks."
            )
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())]) {
                PanelSection(title: "Page limit") {
                    Stepper("\(store.config.cv.pageLimit) page\(store.config.cv.pageLimit == 1 ? "" : "s")", value: $store.config.cv.pageLimit, in: 1...3)
                }
                PanelSection(title: "Language") {
                    Picker("Language", selection: $store.config.cv.targetLanguage) {
                        Text("Decide per application").tag("Auto")
                        Text("English").tag("English")
                        Text("French").tag("French")
                        Text("German").tag("German")
                    }
                    .labelsHidden()
                }
            }
            PanelSection(title: "Photograph") {
                Toggle("Include a professional photo when appropriate for the target country", isOn: $store.config.cv.includePhoto)
                    .toggleStyle(.switch)
            }
            PanelSection(title: "Approved masters", subtitle: "Created by \(store.assistantDisplayName) after the evidence audit. Each new CV must name its source master in tailoring notes.") {
                if store.config.cv.selectedMasterPaths.isEmpty {
                    Text("No masters registered yet. Ask \(store.assistantDisplayName) to audit the evidence bank and build role-family masters.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.config.cv.selectedMasterPaths, id: \.self) { path in
                        Button {
                            store.open(path: path)
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(AppTheme.teal)
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 10))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var integrationSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            PanelSection(title: "Assistant", subtitle: "This controls search execution and the handoffs opened by the app.") {
                Picker("Assistant", selection: Binding(
                    get: { store.assistantProvider },
                    set: { store.setAssistantProvider($0) }
                )) {
                    Text("Codex").tag("codex")
                    Text("Claude Code").tag("claude")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
            }

            PanelSection(title: "Local runtime") {
                VStack(spacing: 12) {
                    integrationStatus(
                        name: "Codex",
                        available: store.codexIsAvailable,
                        detail: store.codexIsAvailable
                            ? "Manual and scheduled searches can execute directly in the selected workspace."
                            : "Install the ChatGPT desktop app or Codex CLI before using direct background search."
                    )
                    Divider()
                    integrationStatus(
                        name: "Claude Code",
                        available: store.claudeCodeIsAvailable,
                        detail: store.claudeCodeIsAvailable
                            ? "Manual and scheduled searches can execute directly in the selected workspace."
                            : "Install the Claude Code CLI before using direct background search. Setup handoffs can still be copied."
                    )
                }
            }

            InlineBanner(
                kind: .info,
                title: store.assistantProvider == "codex" ? "Codex behavior" : "Claude Code behavior",
                message: store.assistantProvider == "codex"
                    ? "Manual and recurring searches run through the local Codex CLI. Setup and evidence review open a visible Codex task because they may require your answers."
                    : "Manual and recurring searches run through the local Claude Code CLI. Setup and evidence review open Claude because they may require your answers."
            )
        }
    }

    private var applicationSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            softwareUpdatePanel
            PanelSection(title: "Workspace folder") {
                Text(store.workspaceURL.path)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                FlowLayout {
                    Button("Choose Folder") { store.chooseWorkspaceFolder() }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Reveal in Finder") { store.revealWorkspace() }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            PanelSection(title: "Guided setup") {
                HStack {
                    Text("Run the first-use assistant again without deleting your leads or documents.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Restart Setup") { store.restartOnboarding() }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            PanelSection(title: "Dedupe registry", subtitle: "Permanent deletion keeps a minimal marker so the automation cannot recommend the same posting again.") {
                Text("\(store.state.tombstones.count) protected posting\(store.state.tombstones.count == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .semibold))
            }
        }
    }

    private var softwareUpdatePanel: some View {
        PanelSection(title: "Software update", subtitle: "Checks the latest stable GitHub release. Updates are verified before installation.") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: updateStatusIcon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(updateStatusColor)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(updateStatusTitle)
                            .font(.system(size: 13, weight: .semibold))
                        Text(updateStatusDetail)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    Text("Installed \(store.currentAppVersion)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if let update = store.availableSoftwareUpdate,
                   !update.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(update.notes)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 5))
                }

                HStack(spacing: 8) {
                    Button {
                        Task { await store.checkForUpdates() }
                    } label: {
                        Label("Check Now", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(updateOperationInProgress)

                    if let update = store.availableSoftwareUpdate {
                        Button {
                            store.installAvailableUpdate()
                        } label: {
                            Label("Install \(update.version)", systemImage: "arrow.down.app.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button {
                            store.openWeb(update.releasePageURL.absoluteString)
                        } label: {
                            Label("Release Notes", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
            }
        }
    }

    private func integrationStatus(name: String, available: Bool, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: available ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(available ? Color.green : AppTheme.amber)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var updateOperationInProgress: Bool {
        switch store.softwareUpdateState {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }

    private var updateStatusTitle: String {
        switch store.softwareUpdateState {
        case .idle: return "Not checked"
        case .checking: return "Checking GitHub"
        case .current: return "Up to date"
        case .available(let update): return "Version \(update.version) is available"
        case .downloading(let version): return "Downloading \(version)"
        case .installing(let version): return "Installing \(version)"
        case .failed: return "Update check failed"
        }
    }

    private var updateStatusDetail: String {
        switch store.softwareUpdateState {
        case .idle: return "The app checks once whenever it opens."
        case .checking: return "Reading the latest stable release metadata."
        case .current(_, let checkedAt): return "Last checked \(checkedAt.formatted(date: .abbreviated, time: .shortened))."
        case .available: return "The archive checksum and app signature will be checked before installation."
        case .downloading: return "Downloading and verifying the release archive."
        case .installing: return "The app will close, replace itself, and reopen."
        case .failed(let message, let checkedAt):
            return "\(message) Last attempted \(checkedAt.formatted(date: .abbreviated, time: .shortened))."
        }
    }

    private var updateStatusIcon: String {
        switch store.softwareUpdateState {
        case .current: return "checkmark.circle.fill"
        case .available: return "arrow.down.circle.fill"
        case .checking, .downloading, .installing: return "clock.arrow.circlepath"
        case .failed: return "exclamationmark.triangle.fill"
        case .idle: return "shippingbox"
        }
    }

    private var updateStatusColor: Color {
        switch store.softwareUpdateState {
        case .current: return .green
        case .available: return AppTheme.teal
        case .failed: return AppTheme.amber
        default: return AppTheme.muted
        }
    }

    private func settingsField(_ label: String, text: Binding<String>) -> some View {
        LabeledField(label: label) {
            TextField(label, text: text)
                .textFieldStyle(AppTextFieldStyle())
        }
    }

    private func commaSeparated(_ values: Binding<[String]>) -> Binding<String> {
        Binding(
            get: { values.wrappedValue.joined(separator: ", ") },
            set: { value in
                values.wrappedValue = value.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    private var customOpportunityFormats: Binding<String> {
        Binding(
            get: {
                store.config.search.opportunityTypes
                    .filter { !OpportunityFormatOptions.common.contains($0) }
                    .joined(separator: ", ")
            },
            set: { value in
                let selectedCommon = store.config.search.opportunityTypes
                    .filter(OpportunityFormatOptions.common.contains)
                let custom = value.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && !OpportunityFormatOptions.common.contains($0) }
                var seen = Set<String>()
                store.config.search.opportunityTypes = (selectedCommon + custom).filter { seen.insert($0).inserted }
            }
        )
    }

    private func toggle(_ value: String, in array: inout [String]) {
        if array.contains(value) {
            array.removeAll { $0 == value }
        } else {
            array.append(value)
        }
    }
}
