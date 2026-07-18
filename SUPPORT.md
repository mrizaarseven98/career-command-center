# Support

Report reproducible problems through [GitHub Issues](https://github.com/mrizaarseven98/career-command-center/issues). Remove personal paths and career information before posting.

Include:

- macOS version and processor type.
- Career Command Center version from **Settings > App**.
- Selected assistant and its version.
- Exact steps, expected result, and actual result.
- A diagnostic summary with personal information removed.

Do not attach CVs, transcripts, access tokens, private posting links, or application documents to a public issue.

## Diagnose the Workspace

In a Codex or Claude task with access to the workspace, enter:

```text
Diagnose Career Command Center and summarize blockers without changing my documents.
```

The diagnostic checks workspace structure, configuration, evidence readiness, master CV registration, lead state, and schedule synchronization.

## Common Problems

### macOS blocks the first launch

Move the app to `/Applications` or `~/Applications`. Control-click `Career Command Center.app`, choose **Open**, and confirm once. The GitHub build is locally signed but not App Store notarized.

### Run Search does not start

Open **Settings > Integration** and confirm the intended assistant is selected and shown as available. Codex requires the ChatGPT desktop app or Codex CLI. Claude requires the Claude Code CLI. A successful start replaces **Run Search Now** with **Stop Search** and exposes **Run Log** under Automation.

### Search finishes with an error

Open **Automation > Run Log**. Authentication, quota, permission, and network failures are reported there. The app refreshes lead state only after the assistant process exits.

### The schedule shows Sync needed

Schedule settings are not considered active merely because they were saved in the app. Use **Open Codex to Register** or the equivalent Claude Code action and complete the assistant task. This registration step opens the assistant because only the assistant can create its own recurring task. **Run Search Now** is separate and executes directly. The app refreshes the sync state when it becomes active and while the Automation screen is open.

### New opportunities are missing

Open **New** and change the found-date filter to **Any date**. New is a time-based view of active To Apply and Saved records; moving a role to Applied or Archive removes it from New. The original discovery timestamp is preserved when a posting is refreshed.

### Personalized questions do not appear

Import source documents or project material, then use the audit action under Questions. Refresh the Questions view after the assistant finishes. A saved answer is not approved automatically; use the review action so the cited source can be checked.

### An archived or deleted opportunity returns

Run the diagnostic. Archive, Recently Deleted, and permanent-delete tombstones all participate in deduplication. The same canonical posting should not be promoted again.

### An update cannot install

Confirm the app is in `/Applications` or `~/Applications` and that the folder is writable. Use **Settings > App > Check Now**. Update failures are recorded in `~/Library/Logs/Career Command Center/update.log`. The updater retains or restores the previous app if the replacement fails verification.

## Security Reports

Do not post private data or exploit details publicly. Open a minimal issue asking for a private reporting channel.
