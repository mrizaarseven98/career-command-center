---
name: career-command-center
description: Install, set up, diagnose, or operate Career Command Center; audit career evidence; generate cited follow-up questions; build role-family master CVs; research targeted jobs or PhDs; tailor application packages; track applications; or synchronize recurring searches with Claude Code.
version: 2.0.1
---

# Career Command Center for Claude Code

Use the native app for intake, questions, opportunity review, lifecycle state, and settings. Use Claude Code for evidence auditing, live research, document generation, validation, and explicitly requested scheduling.

Resolve bundled files through `${CLAUDE_PLUGIN_ROOT}`. Never assume a cache location.

## First Setup

1. Choose a private workspace. Prefer the active project when the user wants it to contain the career workspace; otherwise use `~/Documents/Career Command Center`.
2. Initialize and install without replacing existing user data:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap_workspace.py" "WORKSPACE"
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/install_app.py" --workspace "WORKSPACE" --assistant-provider claude
```

3. Ask the user to complete all seven setup steps. Fresh setup is neutral: do not assume a country, profession, role family, seniority, opportunity format, CV language, photograph policy, or recurring schedule.
4. After setup, read:
   - `Config/command_center_config.json`
   - `Evidence_Bank/intake_answers.md`
   - `${CLAUDE_PLUGIN_ROOT}/references/CV_GENERATION_STANDARD.md`
   - `${CLAUDE_PLUGIN_ROOT}/references/PERSONALIZED_QUESTION_STANDARD.md`
   - `${CLAUDE_PLUGIN_ROOT}/references/WORKSPACE_CONTRACT.md`
5. Inventory and extract relevant CVs, transcripts, certificates, recommendations, work samples, reports, and project files.
6. Build the verified portion of `Verified_Evidence_Ledger.md` and `approved_evidence.json`. Keep unsupported, contradictory, shared, estimated, and unresolved claims clearly separated.
7. Generate only unresolved, source-specific, high-impact questions through `question_cli.py generate`. Every question must cite a workspace-relative source path, a useful locator, and the exact ambiguity. Do not repeat generic onboarding questions or ask for information already clear in a source.
8. If questions need user answers, tell the user they are ready under **Questions** in the app. Stop before final master-CV generation and scheduling.
9. Review saved answers against each cited source. Update approved evidence only where the response and source support it, then record every decision through `question_cli.py review`.
10. When no material question remains open or awaiting review, infer role families only if the config permits it, build evidence-supported role-family master CVs, render and inspect every page, and register approved masters through `register_masters.py`.
11. Run `state_cli.py migrate-assessments` and `doctor.py --strict`. Resolve blockers before package generation or scheduling.

## Scheduling

1. Run `render_automation_spec.py WORKSPACE` and read the complete result.
2. Use one Claude Code `/schedule` job when the result is active. Update the existing matching job instead of creating a duplicate.
3. The scheduled job must have access to the selected local workspace. If the active Claude surface or plan cannot provide that access, explain the exact limitation and leave the app in **Sync needed** state.
4. If the result is paused, pause or remove the existing matching job.
5. Run `mark_automation_synced.py` only after the real scheduled-job operation succeeds. Do not treat saved config as proof that a schedule exists.

## Run Search Now

1. Read the current config on every run and execute the complete prompt from `render_automation_spec.py`.
2. Use live web research. Verify the posting, employer or institution, location, deadline, and working application route on an authoritative source whenever possible.
3. Check active, applied, archived, recently deleted, and tombstoned records before promotion.
4. Write promoted leads only through `state_cli.py upsert`. Never create `manual_check`.
5. Record the completed run through `state_cli.py record-run`, including source coverage, lead count, packages, shortfall, and errors.

## Lifecycle Rules

- Preserve the original `discovered_at` when refreshing a lead.
- Never rediscover applied, archived, deleted, or tombstoned postings.
- Archive is reversible. Recently Deleted is recoverable. Permanent deletion retains a minimal dedupe marker.
- Preserve unknown lead fields and generated application files.
- Store genuine skill or domain gaps in `fit_gaps`.
- Store language, permit, location, travel, and contract conditions in `eligibility_constraints`.
- Store transcripts, certificates, references, deadlines, and upload instructions in `application_requirements`; these never reduce the fit score.

## CV and Cover-Letter Rules

- Read the complete posting and CV standard before drafting.
- Start from one approved role-family master, never an old tailored CV or a blank page.
- Target through evidence selection, order, and truthful terminology. Do not add visible recruiter commentary.
- Never fabricate dates, tools, metrics, ownership, employment facts, publications, language ability, regulatory exposure, or deployment claims.
- Keep measured, estimated, proposed, shared, and individually owned work distinct.
- Use direct, natural cover-letter prose. Avoid generic openings, corporate filler, exaggerated enthusiasm, symmetrical template structure, and contrast formulas.
- Render and inspect PDF and editable output. A package with an evidence, ATS, duplicate, integrity, or visual blocker is not ready.

## Privacy and External Actions

- Treat the workspace as private career data. Read only files needed for the requested operation.
- The app has no developer-operated backend or telemetry.
- Never submit an application, contact an employer, publish a document, or accept terms without explicit instruction for that action.
- Explain before sending career data to an employer portal, converter, connector, or third-party service.

## Diagnose or Update

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.py" "WORKSPACE"
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap_workspace.py" "WORKSPACE"
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/install_app.py" --workspace "WORKSPACE" --assistant-provider claude
```

Never overwrite user documents, evidence, lead state, or generated applications during an update. Read `${CLAUDE_PLUGIN_ROOT}/SUPPORT.md` for installation problems.
