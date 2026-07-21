# Career Command Center

Career Command Center is a native macOS application for targeted job and PhD research, career-evidence review, CV tailoring, and application tracking. It keeps documents and state in a local workspace chosen by the user. Codex or Claude Code performs the research and document work.

## Download the App

GitHub Releases is the primary installation route.

1. [Download the latest macOS release](https://github.com/mrizaarseven98/career-command-center/releases/latest/download/Career-Command-Center-macOS.zip).
2. Open the ZIP and move `Career Command Center.app` to `/Applications` or `~/Applications`.
3. Control-click the app, choose **Open**, and confirm the first launch.
4. Choose Codex or Claude Code and complete the seven setup steps.

The app is a universal Intel and Apple-silicon build for macOS 14 or later. It is locally signed and verified, but it is not App Store notarized, which is why macOS may require the one-time Control-click launch.

The standalone app includes its workflow standards and state tools. A Codex or Claude plugin is optional.

## First Setup

Setup starts without a country, profession, seniority, opportunity type, CV language, photograph policy, or recurring schedule.

1. Choose the local workspace and assistant.
2. Record stable profile facts such as identity, work authorisation, and languages.
3. Import every useful CV, transcript, certificate, recommendation, work sample, report, and project file.
4. Answer the background questions about ownership, outcomes, verified numbers, constraints, and claims to avoid.
5. Set the practical search boundary only after the evidence intake.
6. Choose the CV standard and country-dependent photograph policy.
7. Keep searches manual or request a daily or weekly schedule.

With Codex selected, **Finish Setup** opens a visible Codex task with the workspace and request prefilled; press **Send** once. With Claude Code selected, the app opens Claude when available and copies the prepared request for a new task.

The assistant audits the imported material and writes only source-specific follow-up questions to the app. Each question identifies the file, location, and ambiguity that triggered it. Master CVs and recurring schedules remain blocked until material evidence questions are resolved.

## Opportunity Workflow

- **New** is a discovery inbox. It shows active opportunities by the date they were first found and defaults to the last seven days.
- Every opportunity list can be filtered by **Today**, **Yesterday**, **3 days**, **7 days**, **30 days**, or **Any date**, together with opportunity type and text search.
- **To Apply**, **Saved**, and **Applied** are lifecycle queues.
- **Archive** is reversible and prevents rediscovery.
- **Recently Deleted** is recoverable. Permanent deletion removes posting details but retains a minimal dedupe marker.
- Application documents and portal requirements are shown as a checklist. They do not reduce the evidence-fit score.

Generated application files are never removed when a posting is archived or deleted.

## Assistant Integration

### Codex

**Run Search** executes `codex exec` directly in the selected workspace with live web search enabled. The app shows a running state, a readable log, and a Stop control. Setup and evidence review open visible Codex tasks because they require assistant reasoning and may require user answers.

**Save Schedule** registers a per-user macOS LaunchAgent directly. At the saved time, the signed app runner starts `codex exec` and prevents overlapping searches. Scheduler control files and logs stay in the user's private Application Support directory so macOS privacy controls do not block a workspace stored in Desktop or Documents; the app exposes the current log. The app window may be closed, but the Mac must be on and the user logged in. No Codex Scheduled task or copied prompt is required.

### Claude Code

**Run Search** executes the local Claude Code CLI directly in guarded automatic mode and writes the same visible run log. Setup and evidence review are copied into a Claude Code task. Recurring searches use the same app-owned macOS scheduler and signed runner, so they do not depend on Claude Code `/schedule` or a Team plan.

## Install Through Codex

The GitHub repository also acts as a Codex plugin marketplace:

```bash
codex plugin marketplace add mrizaarseven98/career-command-center
codex plugin add career-command-center@career-command-center-github
```

Start a new Codex task in the folder that should contain or access the private career workspace and enter:

```text
Set up Career Command Center.
```

Codex installs the same native app and opens setup.

## Install Through Claude Code

```bash
claude plugin marketplace add mrizaarseven98/career-command-center
claude plugin install career-command-center@career-command-center
```

Start Claude Code in the folder that should contain or access the private career workspace, then run:

```text
/career-command-center:setup
```

The plugin also provides `/career-command-center:audit-evidence`, `/career-command-center:search-now`, and `/career-command-center:sync-schedule`.

## Updates

The app checks the latest stable GitHub release once when it opens. **Settings > App > Check Now** performs the same check on demand. Installation is offered only when both the app archive and checksum are present. The downloaded checksum, bundle identifier, version, executables, and code signature are verified before replacement. The updater keeps a rollback copy until the new app passes verification.

Move the app into `/Applications` or `~/Applications` before using self-update. A translocated copy launched directly from a download folder cannot replace itself.

## Privacy

There is no Career Command Center account, developer-operated backend, analytics, or telemetry. The app does not upload documents on its own. The configured assistant reads workspace files only when it performs a requested task. Review [PRIVACY.md](PRIVACY.md), [TERMS.md](TERMS.md), and [SUPPORT.md](SUPPORT.md) before using the software.

## Development

Run the complete macOS test gate with:

```bash
APP_ARCHITECTURES='arm64 x86_64' scripts/test_macos_app.sh
```

It tests workspace migration, discovery-date behavior, lifecycle and dedupe rules, Codex and Claude launch arguments, schedule payloads, weekday and weekly cadence handling, overlap prevention, runner status and logs, universal binaries, release extraction, checksum rejection, updater replacement and rollback, signatures, and compatibility fixtures. GitHub Actions runs the same gate before a tagged release is published.

The project is licensed under the MIT License.
