# Career Command Center App Workflow

This file is the operational contract bundled with the native app. The directory containing it is `SYSTEM_ROOT`. Scripts are in `SYSTEM_ROOT/scripts`; reference standards are in `SYSTEM_ROOT/references`. The workspace path is supplied in the user request.

## Safety and Data

- Treat the workspace as private career data. Read only material needed for the requested operation.
- Never submit an application, contact an employer, or accept terms without an explicit request for that exact external action.
- Never invent dates, skills, metrics, ownership, employment facts, publications, language ability, regulatory exposure, or production deployment.
- Preserve unknown lead fields and all user documents.
- Use structured scripts and JSON APIs. Do not rewrite state files with ad hoc text manipulation.

## Finish Setup

1. Read `Config/command_center_config.json`, `Evidence_Bank/intake_answers.md`, and all imported CVs, transcripts, certificates, recommendations, reports, and project files.
2. Read `SYSTEM_ROOT/references/CV_GENERATION_STANDARD.md`, `PERSONALIZED_QUESTION_STANDARD.md`, and `WORKSPACE_CONTRACT.md`.
3. Build or refresh `Evidence_Bank/Verified_Evidence_Ledger.md` and `approved_evidence.json` from defensible evidence only.
4. Generate only unresolved, source-specific, high-impact questions through `SYSTEM_ROOT/scripts/question_cli.py`. Every question must cite a source path, locator, and ambiguity.
5. If questions require user answers, stop and tell the user they are ready in the app. Do not build final master CVs or register a schedule yet.
6. When all questions are resolved, infer role families only when the config permits it, build role-family master CVs using the CV standard, render and inspect them, and register them through `register_masters.py`.
7. Run `state_cli.py migrate-assessments` and `doctor.py --strict`. Resolve every blocker.
8. Run `render_automation_spec.py WORKSPACE`. If the result is active, create or update one matching scheduled task in the assistant named by the request. Use the Codex automation capability for Codex or `/schedule` for Claude Code. If paused, pause or remove the existing matching task. If the selected assistant cannot schedule a task with access to the local workspace, leave the schedule unsynchronized and report that exact blocker.
9. Run `mark_automation_synced.py` only after the scheduled-task operation succeeds.

## Review Evidence Answers

1. Read answered and unable-to-verify questions and reopen every cited source.
2. Add a fact to approved evidence only when the response and source support it. Record unverifiable details as boundaries.
3. Resolve reviewed questions through `question_cli.py review` and create a cited follow-up only when a material ambiguity remains.
4. Continue the setup completion sequence only when no question awaits the user or assistant review.

## Run Search

1. Run `render_automation_spec.py WORKSPACE` and execute the complete rendered prompt.
2. Read current config on every run. Current settings override old reports and memory.
3. Verify every promoted posting and active application route. Use aggregators for discovery and authoritative sources for confirmation when available.
4. Check active, applied, archived, deleted, and tombstoned records before promotion. Never resurface protected opportunities.
5. Use `state_cli.py upsert` for every promoted or updated lead. Never create `manual_check`.
6. Record `discovered_at` once for each new lead and preserve it on updates.
7. Create application packages only when config permits, evidence readiness is clear, and the match meets the CV standard.
8. Finish with `state_cli.py record-run` so the app can display the result.

## CV and Cover Letters

- Read the complete posting and the CV standard before drafting.
- Start from one approved role-family master, never a blank page or an old tailored CV.
- Target through evidence selection and order. Do not add visible fit commentary.
- Keep measured, estimated, shared, and blocked claims distinct.
- Avoid generic openings, corporate filler, exaggerated enthusiasm, symmetrical template prose, contrast formulas, and unsupported claims.
- Render and inspect every delivered document. Do not mark a package ready while a blocker remains.

## Lifecycle

- Valid statuses are `to_apply`, `monitor`, `applied`, `archived`, and `deleted`.
- Archive is reversible. Delete is recoverable until permanent deletion.
- Permanent deletion retains a minimal dedupe tombstone.
- Generated application files are never deleted automatically.
- Application documents and portal logistics belong in `application_requirements`, not `fit_gaps`.
