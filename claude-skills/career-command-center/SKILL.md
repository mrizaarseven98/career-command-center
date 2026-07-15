---
name: career-command-center
description: Install, set up, open, diagnose, or operate Career Command Center; audit CVs, transcripts, and project evidence; generate cited follow-up questions; build role-family master CVs; research targeted jobs or PhDs; tailor application packages; track application status; or synchronize search scheduling with Claude Code.
version: 1.4.0
---

# Career Command Center for Claude

Use the native app for user input and application lifecycle management. Use Claude for evidence auditing, live research, document generation, quality review, and explicitly requested scheduled work.

All bundled paths must be resolved through `${CLAUDE_PLUGIN_ROOT}`. Never assume where Claude cached the plugin.

## First Setup

1. Choose a private workspace. Prefer the current project when the user wants the career workspace there; otherwise use `~/Documents/Career Command Center`.
2. Initialize and install:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap_workspace.py" "WORKSPACE"
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/install_app.py" --workspace "WORKSPACE" --assistant-provider claude
```

3. Ask the user to complete every app setup step and import all useful CVs, transcripts, certificates, recommendations, reports, and project files. Fresh setup is neutral: do not infer countries, roles, seniority, language, photo policy, or scheduling before reading their evidence and preferences.
4. When setup is complete, run `doctor.py`, then read the config, intake answers, workspace contract, personalized-question standard, and CV-generation standard.
5. Audit imported evidence before writing a master CV:
   - Inventory and extract the relevant source files.
   - Separate verified facts, estimates, shared work, contradictions, unsupported claims, and unresolved high-impact gaps.
   - Generate no more than 12 source-specific questions. Every question must cite a workspace-relative file path and useful locator and explain why the answer matters.
   - Validate and write the queue through `question_cli.py generate`; never edit the question bank with ad hoc string replacement.
6. Let the user answer in the app. Review `answered` and `unable_to_verify` items against their cited sources, update the verified evidence ledger and `approved_evidence.json`, then record decisions through `question_cli.py review`.
7. Infer or confirm coherent role families only after the evidence audit. Build role-family master CVs using the bundled CV standard, render them, and inspect every page before registering approved masters.
8. Run `state_cli.py --workspace "WORKSPACE" migrate-assessments` and `doctor.py "WORKSPACE" --strict`. Resolve blockers before enabling package generation or recurring search.

## Scheduling

Career workspaces contain local private documents, so prefer a Claude Code Desktop local scheduled task when recurring search is requested. Do not silently substitute a cloud routine, because cloud routines do not have the same local-file access. Do not treat `/loop` as durable scheduling; it is session-scoped and recurring loops expire.

1. Render the current specification with `render_automation_spec.py WORKSPACE`.
2. If the result is `PAUSED`, remove or disable the existing Career Command Center scheduled task when the user asks.
3. If the result is `ACTIVE`, create or update one Desktop local scheduled task using the rendered prompt and cadence. Never create duplicates.
4. If this Claude surface cannot create Desktop tasks, give the user the exact rendered prompt and schedule to enter in Desktop. Do not mark synchronization complete until the user confirms the task exists.
5. After confirmed synchronization, run `mark_automation_synced.py WORKSPACE --automation-id ID`.

## Run a Search Now

Read the current config and execute the rendered automation prompt in the active session. Use live web research because postings expire and requirements change. Verify canonical employer or institution pages and application routes before promoting a lead.

Use `state_cli.py upsert` for promoted leads and `state_cli.py record-run` at completion. Never directly rewrite application state with string manipulation.

## Lifecycle Rules

- Never rediscover applied, archived, recently deleted, or tombstoned postings.
- Promote a verified opportunity to the queue or omit it; never create a vague manual-check state.
- Archive is reversible. Delete remains recoverable until permanent deletion.
- Never delete generated application files automatically.
- Fit scores measure evidence alignment. Deadlines, required attachments, and submission logistics are not fit penalties.

## CV Rules

- Build a verified evidence foundation before tailoring.
- Start each tailored CV from the closest approved role-family master.
- Keep fixed facts and core accomplishments stable.
- Target through evidence selection and ordering, not visible fit commentary.
- Never fabricate skills, dates, metrics, ownership, publications, language ability, or eligibility.
- Keep output ATS-readable and visually restrained. Render and inspect every delivered PDF.
- Record strategy version, base master, and evidence IDs in tailoring notes.

## Privacy and External Actions

- Treat the workspace as private career data. Read only what is needed for the requested workflow.
- The app has no developer-operated backend or telemetry.
- Never submit an application, send a message, contact a recruiter, publish a document, or accept legal terms without the user's explicit instruction for that action.
- Explain before sending career data to any employer portal, converter, connector, or third-party service.

## Diagnostics

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.py" "WORKSPACE"
```

For installation problems, read `${CLAUDE_PLUGIN_ROOT}/SUPPORT.md`.
